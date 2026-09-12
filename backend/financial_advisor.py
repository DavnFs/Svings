"""
Financial Advisor AI Module for CatatUang Bot
Provides intelligent financial recommendations and analysis
"""
import json
import os
try:
    import requests
except Exception:
    requests = None
from datetime import datetime, timedelta
from typing import Dict, List, Any
import hashlib
import time
from pathlib import Path

# Load environment variables from .env file if python-dotenv is installed
try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    # dotenv not installed in this environment; rely on OS environment variables
    pass

class FinancialAdvisor:
    def __init__(self):
        # Only Groq is supported in this project (self-use)
        self.groq_api_key = os.getenv('GROQ_API_KEY')
        # Allow selecting Groq model via env var, default to Groq's gpt-120b-oss
        self.groq_model = os.getenv('GROQ_MODEL', 'gpt-oss-120b')
        # Groq runtime tuning (can override for robust responses)
        try:
            self.groq_temperature = float(os.getenv('GROQ_TEMPERATURE', '1'))
        except Exception:
            self.groq_temperature = 1
        try:
            self.groq_max_tokens = int(os.getenv('GROQ_MAX_TOKENS', '500'))
        except Exception:
            self.groq_max_tokens = 500
        try:
            self.groq_top_p = float(os.getenv('GROQ_TOP_P', '1.0'))
        except Exception:
            self.groq_top_p = 1.0

        # default toggle: include a short, user-facing rationale with responses
        self.include_reasoning_default = os.getenv('GROQ_INCLUDE_REASONING', 'false').lower() in ('1', 'true', 'yes')

        # Default provider selection
        self.selected_provider = self._select_provider()
        
    def _select_provider(self):
        """Select provider: only Groq or local fallback"""
        if self.groq_api_key:
            return 'groq'
        return 'local'

    # ---------------------------
    # Session & Cache utilities
    # ---------------------------
    def _ensure_cache_dirs(self):
        base = Path('.cache')
        (base / 'chat_sessions').mkdir(parents=True, exist_ok=True)
        (base / 'ai_cache').mkdir(parents=True, exist_ok=True)
        return base

    def _cache_key(self, prompt: str) -> str:
        return hashlib.sha256(prompt.encode('utf-8')).hexdigest()

    def _get_cached_response(self, key: str, ttl: int) -> Any:
        cache_dir = self._ensure_cache_dirs() / 'ai_cache'
        cache_file = cache_dir / f"{key}.json"
        if not cache_file.exists():
            return None
        try:
            meta = json.loads(cache_file.read_text())
            if time.time() - meta.get('ts', 0) > ttl:
                return None
            return meta.get('response')
        except Exception:
            return None

    def _set_cached_response(self, key: str, response: Any):
        cache_dir = self._ensure_cache_dirs() / 'ai_cache'
        cache_file = cache_dir / f"{key}.json"
        meta = {'ts': time.time(), 'response': response}
        try:
            cache_file.write_text(json.dumps(meta))
        except Exception:
            pass

    def _load_session(self, user_id: str) -> Dict:
        base = self._ensure_cache_dirs() / 'chat_sessions'
        f = base / f"{user_id}.json"
        if not f.exists():
            session = {'messages': [], 'memory': ''}
            f.write_text(json.dumps(session))
            return session
        try:
            return json.loads(f.read_text())
        except Exception:
            return {'messages': [], 'memory': ''}

    def _save_session(self, user_id: str, session: Dict):
        base = self._ensure_cache_dirs() / 'chat_sessions'
        f = base / f"{user_id}.json"
        try:
            f.write_text(json.dumps(session))
        except Exception:
            pass

    # Public chat API: stateful, multi-turn, with caching
    def chat_with_user(self, user_id: str, message: str, user_profile: Dict = None, *, cache_enabled: bool = True, verbose: bool = False, with_reasoning: bool = False) -> str:
        """Stateful multi-turn chat. Uses session memory and caches similar prompts.

        - user_id: unique identifier per user (telegram username/id)
        - message: user message (string)
        - user_profile: optional financial data to build memory
        - cache_enabled: whether to use rate-limited cache
        """
        # Load session and possibly populate memory
        session = self._load_session(user_id)

        if user_profile:
            # Always update memory with latest profile data
            try:
                # Use detailed context for better AI awareness
                memory = self._prepare_detailed_context(user_profile)
            except Exception:
                try:
                    memory = self._prepare_user_context(user_profile)
                except Exception:
                    memory = ''
            session['memory'] = memory

        # Keep only last N messages
        max_history = 8
        history = session.get('messages', [])[-max_history:]

        # Build a single prompt combining memory, history and new message
        system_prompt = ''
        if session.get('memory'):
            system_prompt = f"Memory user:\n{session['memory']}\n---\n"

        history_text = ''
        for m in history:
            role = m.get('role', 'user')
            txt = m.get('content', '')
            history_text += f"{role.upper()}: {txt}\n"

        combined_prompt = f"{system_prompt}{history_text}USER: {message}\nASSISTANT:"

        # Check cache
        key = self._cache_key(combined_prompt)
        cache_ttl = int(os.getenv('CACHE_TTL_SECONDS', '300'))
        if cache_enabled:
            cached = self._get_cached_response(key, cache_ttl)
            if cached:
                # append user message to session and return cached
                session.setdefault('messages', []).append({'role': 'user', 'content': message})
                session.setdefault('messages', []).append({'role': 'assistant', 'content': cached})
                self._save_session(user_id, session)
                return cached

        # detect if user explicitly asks for more detail or asks for reasons
        detail_keywords = ['jelas', 'detail', 'lebih lengkap', 'lebih jelas', 'penjelasan']
        reason_keywords = ['mengapa', 'kenapa', 'alasan', 'why']
        if any(k in message.lower() for k in detail_keywords):
            verbose = True
        if any(k in message.lower() for k in reason_keywords):
            with_reasoning = True

        # call AI
        response = self._get_ai_response(combined_prompt, verbose=verbose, with_reasoning=with_reasoning)

        # save to cache and session
        if cache_enabled:
            try:
                self._set_cached_response(key, response)
            except Exception:
                pass

        session.setdefault('messages', []).append({'role': 'user', 'content': message})
        session.setdefault('messages', []).append({'role': 'assistant', 'content': response})
        # trim history before save
        session['messages'] = session['messages'][-(max_history*2):]
        self._save_session(user_id, session)

        return response
    
    def get_transaction_advice(self, amount: float, category: str, description: str, user_data: Dict) -> str:
        """Get immediate advice when user inputs a transaction"""
        # Prepare context from user's financial data
        context = self._prepare_user_context(user_data)

        carry_over = user_data.get('carry_over_balance', 0)
        total_income = user_data.get('total_income', 0)
        total_expense = user_data.get('total_expense', 0)

        # Expense dicatat positif → tambahkan ke total_expense
        new_total_expense = total_expense + float(amount)
        current_month_balance_after = total_income - new_total_expense
        cumulative_balance = carry_over + current_month_balance_after

        # Default saving target
        saving_target = 1_000_000
        available_after_saving = max(0, current_month_balance_after - saving_target)

        # Format angka
        formatted_amount = f"Rp {amount:,.0f}".replace(",", ".")
        formatted_month_balance = f"Rp {current_month_balance_after:,.0f}".replace(",", ".")
        formatted_cumulative = f"Rp {cumulative_balance:,.0f}".replace(",", ".")
        formatted_saving_target = f"Rp {saving_target:,.0f}".replace(",", ".")
        formatted_available = f"Rp {available_after_saving:,.0f}".replace(",", ".")

        # Prompt untuk provider Groq
        prompt = f"""
        Kamu adalah advisor keuangan yang ramah dan membantu. User baru saja input transaksi:

        Transaksi: {formatted_amount} untuk {category} - {description}

        Data keuangan user (sebelum transaksi ini):
        {context}

        Setelah mencatat transaksi ini:
        - Sisa saldo bulan ini: {formatted_month_balance}
        - Saldo total akumulatif: {formatted_cumulative}
        - Target tabungan bulanan: {formatted_saving_target}
        - Sisa yang aman digunakan setelah tabungan: {formatted_available}

        Berikan 2–3 saran singkat yang:
        1. Positif, ramah, dan actionable
        2. Relevan dengan kategori transaksi
        3. Jika pengeluaran besar, beri peringatan
        4. Jika pemasukan, sarankan alokasi ke tabungan/investasi
        """

        # Jika provider Groq tersedia → gunakan
        if self.selected_provider == 'groq' and requests:
            return self._get_ai_response(prompt, with_reasoning=False)

        # Local deterministic fallback
        advice_lines = []
        advice_lines.append("💡 Tips:")

        cat = (category or "").lower()
        percent = (amount / max(1, total_income or 1)) * 100

        if amount > 0:  # Expense
            if "makan" in cat or "food" in cat or "resto" in cat:
                advice_lines.append("🍱 Coba meal prep atau masak sendiri, bisa hemat 30–50% per bulan.")
            elif "transport" in cat or "ojek" in cat or "grab" in cat:
                advice_lines.append("🚌 Gunakan transport umum / beli tiket bulanan untuk hemat biaya transport.")
            elif "hiburan" in cat:
                advice_lines.append("🎮 Batasi hiburan maksimal 10% dari income agar tabungan tetap aman.")
            else:
                advice_lines.append("🔎 Pastikan ini kebutuhan, bukan keinginan. Pakai aturan 24 jam sebelum belanja besar.")

            if percent > 30:
                advice_lines.append(f"⚠️ Transaksi ini {percent:.1f}% dari income bulan ini, cukup besar. Pertimbangkan alternatif lebih murah.")
        else:  # Income
            advice_lines.append(f"💰 Pemasukan baru! Sisihkan 20–30% langsung ke tabungan/investasi ({int(abs(amount)*0.2):,}–{int(abs(amount)*0.3):,}).")

        # Tambahkan info saldo
        advice_lines.append("")
        advice_lines.append(f"📊 Sisa Bulan Ini: {formatted_month_balance}")
        advice_lines.append(f"🧾 Saldo Akumulatif: {formatted_cumulative}")
        advice_lines.append(f"💎 Target Tabungan: {formatted_saving_target}")
        advice_lines.append(f"💵 Bisa Dipakai (aman): {formatted_available}")

        return "\n".join(advice_lines)

    def get_monthly_advice(self, user_data: Dict) -> str:
        """Generate monthly financial advice based on trends and targets"""
        try:
            total_income = user_data.get('total_income', 0)
            total_expense = user_data.get('total_expense', 0)
            categories = user_data.get('categories', {})  # misal {"makanan": 1200000, "transport": 500000}
            carry_over = user_data.get('carry_over_balance', 0)

            saving_target = 1_000_000
            balance = total_income - total_expense
            available_after_saving = max(0, balance - saving_target)

            # Format angka
            formatted_income = f"Rp {total_income:,.0f}".replace(",", ".")
            formatted_expense = f"Rp {total_expense:,.0f}".replace(",", ".")
            formatted_balance = f"Rp {balance:,.0f}".replace(",", ".")
            formatted_saving = f"Rp {saving_target:,.0f}".replace(",", ".")
            formatted_available = f"Rp {available_after_saving:,.0f}".replace(",", ".")

            # Analisis proporsi kategori
            insights = []
            if total_expense > 0:
                for cat, val in categories.items():
                    prop = (val / total_expense) * 100
                    if prop > 30:
                        insights.append(f"⚠️ Pengeluaran {cat.title()} mencapai {prop:.1f}% dari total, cukup tinggi.")
                    elif prop > 20:
                        insights.append(f"ℹ️ Pengeluaran {cat.title()} {prop:.1f}% — masih aman, tapi bisa dioptimalkan.")

            # Tabungan
            if balance < saving_target:
                insights.append("⚠️ Saldo bulan ini belum mencapai target tabungan Rp 1.000.000. Prioritaskan kebutuhan pokok.")
            else:
                insights.append(f"✅ Kamu sudah bisa menabung Rp {saving_target:,} bulan ini.")

            # Buat teks final
            msg = [
                "📅 **Laporan Bulanan**",
                f"💰 Total Pemasukan: {formatted_income}",
                f"💸 Total Pengeluaran: {formatted_expense}",
                f"📊 Saldo Akhir: {formatted_balance}",
                f"💎 Target Tabungan: {formatted_saving}",
                f"💵 Bisa Dipakai: {formatted_available}",
                "",
                "🔎 Insight Bulanan:"
            ]

            if insights:
                msg.extend(insights)
            else:
                msg.append("✅ Pengeluaran bulan ini masih dalam batas sehat (tidak ada kategori >20%).")

            return "\n".join(msg)

        except Exception as e:
            return f"❌ Gagal membuat laporan bulanan: {str(e)}"


    def get_monthly_analysis(self, user_data: Dict) -> str:
        """Generate comprehensive monthly financial analysis"""
        
        context = self._prepare_detailed_context(user_data)
        
        prompt = f"""
        Analisis data keuangan user berikut dan berikan rekomendasi:
        
        {context}
        
        Berikan analisis dalam format:
        📊 ANALISIS KEUANGAN BULAN INI
        
        💰 Ringkasan:
        [ringkasan pendapatan vs pengeluaran]
        
        📈 Tren Pengeluaran:
        [kategori terbesar dan polanya]
        
        💡 Rekomendasi:
        [3 saran konkret untuk bulan depan]
        
        🎯 Target Hemat:
        [target realistis yang bisa dicapai]
        """
        
        return self._get_ai_response(prompt)
    
    def get_budget_recommendation(self, monthly_income: float, user_data: Dict) -> str:
        """Generate personalized budget recommendations with historical context"""
        
        # Extract historical data for better recommendations
        carry_over_balance = user_data.get('carry_over_balance', 0)
        avg_monthly_expense = user_data.get('avg_monthly_expense', 0)
        historical_pattern = user_data.get('historical_spending_pattern', [])
        months_with_data = user_data.get('months_with_data', 0)
        current_expense = user_data.get('total_expense', 0)
        
        # Build historical context for AI
        historical_context = ""
        if months_with_data > 0 and avg_monthly_expense > 0:
            historical_context = f"""
        
        DATA HISTORICAL USER:
        - Rata-rata pengeluaran bulanan: {avg_monthly_expense:,.0f} IDR
        - Saldo carry-over: {carry_over_balance:,.0f} IDR
        - Data tersedia untuk: {months_with_data} bulan
        - Pengeluaran bulan ini: {current_expense:,.0f} IDR
        """
        
        if len(historical_pattern) >= 2:
            trend = "menurun" if historical_pattern[0] > historical_pattern[-1] else "meningkat"
            historical_context += f"- Trend pengeluaran: {trend} dalam 3 bulan terakhir\n"
        
        prompt = f"""
        User memiliki penghasilan bulanan: {monthly_income:,.0f} IDR
        {historical_context}
        
        Berikan rekomendasi budget yang REALISTIS berdasarkan pola pengeluaran historis user, menggunakan prinsip 50/30/20 yang disesuaikan:
        
        Format response:
        💰 REKOMENDASI BUDGET BULANAN
        
        🏠 Kebutuhan Pokok (50%): {monthly_income*0.5:,.0f} IDR
        - Sewa/KPR, listrik, air, internet
        - Makanan pokok, transport kerja
        - Asuransi kesehatan
        
        🎯 Keinginan (30%): {monthly_income*0.3:,.0f} IDR  
        - Hiburan, nongkrong, hobi
        - Shopping non-esensial
        - Traveling
        
        💎 Tabungan & Investasi (20%): {monthly_income*0.2:,.0f} IDR
        - Emergency fund (6-12 bulan pengeluaran)
        - Investasi jangka panjang
        - Dana pensiun
        
        💡 ANALISIS BERDASARKAN HISTORICAL DATA:
        [Bandingkan dengan pola pengeluaran historis user. Apakah budget ini realistis? Ada saldo carry-over yang perlu dipertimbangkan?]
        
        🎯 REKOMENDASI KHUSUS:
        [Saran spesifik berdasarkan trend pengeluaran dan saldo carry-over user]
        """
        
        return self._get_ai_response(prompt)
    
    def check_budget_feasibility(self, budget_amount: float, duration_days: int, user_data: Dict = None) -> str:
        """Check if a budget is feasible for a specific duration and provide daily spending advice"""
        
        daily_budget = budget_amount / duration_days
        
        # Get user's typical spending pattern if available
        context = ""
        if user_data:
            avg_daily = user_data.get('daily_average', 0)
            if avg_daily > 0:
                context = f"Rata-rata pengeluaran harian Anda biasanya: {avg_daily:,.0f} IDR"
        
        prompt = f"""
        User bertanya apakah budget {budget_amount:,.0f} IDR cukup untuk hidup selama {duration_days} hari.
        
        Budget per hari: {daily_budget:,.0f} IDR
        {context}
        
        Analisis dan berikan rekomendasi dalam format:
        
        💰 ANALISIS BUDGET {duration_days} HARI
        
        💵 Total Budget: {budget_amount:,.0f} IDR
        📅 Durasi: {duration_days} hari
        🎯 Budget Harian: {daily_budget:,.0f} IDR
        
        ✅ KELAYAKAN:
        [Apakah budget ini realistis? Cukup/kurang/berlebih dan kenapa]
        
        📊 REKOMENDASI ALOKASI HARIAN:
        🍽️ Makanan: [jumlah] IDR ({daily_budget*0.4:.0f} IDR - 40%)
        🚗 Transport: [jumlah] IDR ({daily_budget*0.2:.0f} IDR - 20%)
        🎯 Lain-lain: [jumlah] IDR ({daily_budget*0.3:.0f} IDR - 30%)
        💎 Cadangan: [jumlah] IDR ({daily_budget*0.1:.0f} IDR - 10%)
        
        💡 TIPS HEMAT:
        [3 tips praktis untuk mengoptimalkan budget ini]
        
        ⚠️ PERINGATAN:
        [Hal-hal yang perlu diwaspadai dengan budget ini]
        """
        
        return self._get_ai_response(prompt)
    
    def get_daily_spending_plan(self, daily_budget: float, priorities: List[str] = None) -> str:
        """Generate daily spending plan based on budget"""
        
        if not priorities:
            priorities = ["makanan", "transport", "kebutuhan_pokok"]
        
        prompt = f"""
        User memiliki budget harian {daily_budget:,.0f} IDR dan ingin rencana pengeluaran.
        
        Prioritas pengeluaran: {', '.join(priorities)}
        
        Berikan rencana dalam format:
        
        📅 RENCANA PENGELUARAN HARIAN
        💰 Budget: {daily_budget:,.0f} IDR
        
        🎯 ALOKASI SMART:
        🍽️ Makanan (sarapan + makan siang + makan malam): {daily_budget*0.45:.0f} IDR
        🚗 Transport (PP kerja/aktivitas): {daily_budget*0.25:.0f} IDR
        ☕ Jajan/Minuman: {daily_budget*0.15:.0f} IDR
        🎯 Lain-lain (darurat/tak terduga): {daily_budget*0.10:.0f} IDR
        💎 Sisa untuk tabung: {daily_budget*0.05:.0f} IDR
        
        💡 STRATEGI HEMAT:
        [Tips konkret untuk stay within budget]
        
        📱 TRACKING HARIAN:
        [Cara simple track pengeluaran per hari]
        """
        
        return self._get_ai_response(prompt)

    # ---------------------------
    # Advanced utility methods (Groq-first, local fallback)
    # ---------------------------
    def estimate_daily_allowance(self, balance: int, days: int, non_cook: bool = False, with_reasoning: bool = False) -> str:
        """Estimate how much user can spend per day given remaining balance and days to survive.

        If non_cook=True, allocate larger share for food.
        """
        if days <= 0:
            return "⚠️ Hari harus > 0"

        daily = int(balance // days)
        # allocation
        if non_cook:
            food_pct = 0.6
            transport_pct = 0.15
            other_pct = 0.25
        else:
            food_pct = 0.45
            transport_pct = 0.25
            other_pct = 0.30

        food = int(daily * food_pct)
        transport = int(daily * transport_pct)
        other = int(daily * other_pct)

        result = (
            f"📅 Alokasi harian dari saldo Rp {balance:,} untuk {days} hari:\n"
            f"→ Maksimal pengeluaran per hari: Rp {daily:,}\n"
            f"• Makanan: Rp {food:,} ({int(food_pct*100)}%)\n"
            f"• Transport: Rp {transport:,} ({int(transport_pct*100)}%)\n"
            f"• Lain-lain / Cadangan: Rp {other:,} ({int(other_pct*100)}%)\n"
            f"\nTips: Sesuaikan prioritas (mis. lebih transport jika butuh berangkat kerja)."
        )
        if with_reasoning:
            result += "\n\nAlasan singkat:\n1. Pembagian berdasarkan prioritas kebutuhan.\n2. Alokasi disesuaikan untuk target jangka pendek."
        return result


    def advanced_budget_plan(self, monthly_income: int, user_data: Dict, savings_goal: int = None, with_reasoning: bool = False) -> str:
        """Generate an actionable monthly plan with targets, based on historical user data.

        Groq model will be used when available; otherwise produce deterministic plan.
        """
        # Build brief context
        ctx = self._prepare_detailed_context(user_data)
        prompt = (
            f"Anda adalah personal financial advisor untuk user tunggal. "
            f"Buatkan rencana budget bulanan yang sangat konkrit dan terukur.\n\n"
            f"DATA PENGGUNA:\n{ctx}\n\n"
            f"INSTRUKSI:\nBerikan: 1) Breakdown budget (kebutuhan/keinginan/tabungan) 2) Target tabungan mingguan dan bulanan 3) 3 langkah konkret untuk mencapai target 4) rekomendasi investasi (jika ada)"
        )

        if self.selected_provider == 'groq' and requests:
            try:
                return self._call_groq_api(prompt, include_reasoning=with_reasoning)
            except Exception as e:
                print(f"Groq error: {e} - fallback ke rule-based plan")

        # Local deterministic fallback
        base_income = monthly_income
        needs = int(base_income * 0.5)
        wants = int(base_income * 0.3)
        save = int(base_income * 0.2)
        carry = user_data.get('carry_over_balance', 0)

        lines = []
        lines.append(f"💰 Rencana Budget Bulanan untuk pendapatan Rp {base_income:,}")
        lines.append(f"• Kebutuhan (50%): Rp {needs:,}")
        lines.append(f"• Keinginan (30%): Rp {wants:,}")
        lines.append(f"• Tabungan & Investasi (20%): Rp {save:,}")
        if savings_goal:
            months = max(1, int(savings_goal // save))
            lines.append(f"Target menabung Rp {savings_goal:,} membutuhkan ~{months} bulan (asumsi simpan Rp {save:,}/bln)")

        lines.append('\n3 Langkah Konkret:')
        lines.append('1. Otomatisasi tabungan: pindahkan Rp {0:,}/bln ke rekening tabungan setiap gaji.'.format(save))
        lines.append('2. Tinjau top 3 kategori pengeluaran tiap minggu dan kurangi 1 pos non-esensial.')
        lines.append('3. Tetapkan target mingguan kecil (mis. hemat Rp 50.000/minggu) dan ukur.')

        if carry and carry > 0:
            lines.append(f"\nSaldo carry-over: Rp {carry:,}. Gunakan sebagian untuk kebutuhan darurat, sisihkan sisanya ke tabungan.")

        lines.append('\nRekomendasi investasi (konservatif): reksadana pasar uang atau deposito untuk dana darurat. Untuk investasi aktif, alokasikan maksimal 10% dari tabungan bulanan.')

        return '\n'.join(lines)

    def advanced_advice(self, amount: float, category: str, description: str, user_data: Dict, depth: int = 3, with_reasoning: bool = False) -> str:
        """Provide multi-point, actionable advice for a transaction. depth controls number of suggestions."""
        prompt = (
            f"User mengeluarkan Rp {amount:,.0f} untuk {category} - {description}.\n"
            f"Berikan {depth} rekomendasi konkret untuk mengurangi pengeluaran serupa di masa depan, "
            f"alternatif yang lebih murah, dan estimasi penghematan bulanan jika saran diterapkan. Sertakan langkah implementasi yang terukur."
        )

        if self.selected_provider == 'groq' and requests:
            try:
                return self._call_groq_api(prompt, include_reasoning=with_reasoning)
            except Exception as e:
                print(f"Groq error: {e} - fallback ke rule-based advice")

        # Local fallback: create structured advice
        adv = []
        adv.append(f"💡 Ringkasan: Pengeluaran Rp {amount:,.0f} untuk {category} - {description}.")
        adv.append('\nRekomendasi:')
        # simple heuristics
        for i in range(1, depth + 1):
            if category == 'makanan':
                if i == 1:
                    adv.append(f"{i}. Pilih menu ekonomis (estimasi hemat 20%).")
                elif i == 2:
                    adv.append(f"{i}. Kurangi frekuensi makan di luar 1x seminggu (hemat ~Rp 100.000/bln).")
                else:
                    adv.append(f"{i}. Gunakan promo atau loyalty (hemat variabel).")
            elif category == 'transport':
                adv.append(f"{i}. Pertimbangkan transportasi umum atau carpool untuk kurangi biaya.")
            else:
                adv.append(f"{i}. Evaluasi apakah pembelian ini esensial; tunda 24 jam untuk keputusan pembelian.")

        adv.append('\nEstimasi penghematan bulanan: mulai dari Rp 50.000 - Rp 300.000 tergantung konsistensi.')
        adv.append('\nLangkah implementasi: catat, target mingguan, dan review setiap minggu.')
        out = '\n'.join(adv)
        if with_reasoning:
            out += '\n\nAlasan singkat:\n1. Fokus menurunkan frekuensi atau biaya rata-rata per kejadian.\n2. Pilih alternatif yang lebih murah namun masih memenuhi kebutuhan.\n3. Automasi penghematan untuk konsistensi.'
        return out
    
    def _prepare_user_context(self, user_data: Dict) -> str:
        """Prepare user context with historical data for better AI analysis"""
        
        total_income = user_data.get('total_income', 0)
        total_expense = user_data.get('total_expense', 0)
        categories = user_data.get('categories', {})
        
        # New historical data fields
        carry_over_balance = user_data.get('carry_over_balance', 0)
        effective_balance = user_data.get('effective_balance', 0)
        avg_monthly_expense = user_data.get('avg_monthly_expense', 0)
        months_with_data = user_data.get('months_with_data', 0)
        historical_pattern = user_data.get('historical_spending_pattern', [])
        
        context = f"""
        BULAN INI:
        - Pemasukan: {total_income:,.0f} IDR
        - Pengeluaran: {total_expense:,.0f} IDR
        - Saldo bulan ini: {total_income - total_expense:,.0f} IDR
        
        HISTORICAL DATA:
        - Saldo carry-over dari bulan lalu: {carry_over_balance:,.0f} IDR
        - Total saldo efektif: {effective_balance:,.0f} IDR
        - Rata-rata pengeluaran bulanan: {avg_monthly_expense:,.0f} IDR
        - Data tersedia untuk: {months_with_data} bulan
        """
        
        # Add spending trend analysis if historical data available
        if len(historical_pattern) >= 2:
            trend_direction = "naik" if historical_pattern[0] > historical_pattern[-1] else "turun"
            context += f"- Trend pengeluaran: {trend_direction} dalam 3 bulan terakhir\n"
        
        context += "\nTop 3 kategori pengeluaran bulan ini:\n"        # Add top spending categories
        sorted_categories = sorted(categories.items(), key=lambda x: x[1], reverse=True)[:3]
        for cat, amount in sorted_categories:
            percentage = (amount / total_expense * 100) if total_expense > 0 else 0
            context += f"- {cat}: {amount:,.0f} IDR ({percentage:.1f}%)\n"
        
        return context
    
    def _prepare_detailed_context(self, user_data: Dict) -> str:
        """Prepare comprehensive detailed context for in-depth analysis"""
        
        total_income = user_data.get('total_income', 0)
        total_expense = user_data.get('total_expense', 0)
        categories = user_data.get('categories', {})
        transactions_count = user_data.get('transactions_count', 0)
        
        # Historical data
        carry_over_balance = user_data.get('carry_over_balance', 0)
        effective_balance = user_data.get('effective_balance', 0)
        current_month_balance = user_data.get('current_month_balance', 0)
        total_income_all_time = user_data.get('total_income_all_time', 0)
        total_expense_all_time = user_data.get('total_expense_all_time', 0)
        avg_monthly_expense = user_data.get('avg_monthly_expense', 0)
        months_with_data = user_data.get('months_with_data', 0)
        historical_pattern = user_data.get('historical_spending_pattern', [])
        first_transaction_date = user_data.get('first_transaction_date', '')
        
        context = f"""
        DATA KEUANGAN LENGKAP:
        
        BULAN BERJALAN:
        - Pemasukan bulan ini: {total_income:,.0f} IDR
        - Pengeluaran bulan ini: {total_expense:,.0f} IDR
        - Saldo bulan ini: {current_month_balance:,.0f} IDR
        - Jumlah transaksi: {transactions_count}
        
        HISTORICAL OVERVIEW:
        - Saldo dari bulan-bulan sebelumnya: {carry_over_balance:,.0f} IDR
        - Total saldo efektif saat ini: {effective_balance:,.0f} IDR
        - Total pemasukan all-time: {total_income_all_time:,.0f} IDR
        - Total pengeluaran all-time: {total_expense_all_time:,.0f} IDR
        - Rata-rata pengeluaran per bulan: {avg_monthly_expense:,.0f} IDR
        - Data tersedia untuk: {months_with_data} bulan
        """
        
        if first_transaction_date:
            context += f"- Mulai tracking sejak: {first_transaction_date}\n"
        
        # Historical spending pattern analysis
        if len(historical_pattern) >= 2:
            context += f"\nTREND PENGELUARAN (3 bulan terakhir):\n"
            for i, amount in enumerate(historical_pattern):
                context += f"- Bulan {i+1} lalu: {amount:,.0f} IDR\n"
            
            # Calculate trend
            if historical_pattern[0] > historical_pattern[-1]:
                trend_pct = ((historical_pattern[0] - historical_pattern[-1]) / historical_pattern[-1]) * 100
                context += f"- Trend: MENURUN {trend_pct:.1f}% (bagus!)\n"
            else:
                trend_pct = ((historical_pattern[-1] - historical_pattern[0]) / historical_pattern[0]) * 100
                context += f"- Trend: NAIK {trend_pct:.1f}% (perlu perhatian)\n"
        
        # Spending ratio analysis
        if effective_balance != 0:
            if carry_over_balance > 0:
                sustainability_months = carry_over_balance / avg_monthly_expense if avg_monthly_expense > 0 else 0
                context += f"\nANALISIS SUSTAINABILITY:\n"
                context += f"- Dengan saldo carry-over, bisa bertahan {sustainability_months:.1f} bulan lagi\n"
            
            if total_income > 0:
                expense_ratio = (total_expense / total_income) * 100
                context += f"- Expense ratio bulan ini: {expense_ratio:.1f}%\n"
        
        context += "\nBREAKDOWN KATEGORI BULAN INI:\n"        # Detailed category breakdown
        sorted_categories = sorted(categories.items(), key=lambda x: x[1], reverse=True)
        for cat, amount in sorted_categories:
            percentage = (amount / total_expense * 100) if total_expense > 0 else 0
            context += f"- {cat.title()}: {amount:,.0f} IDR ({percentage:.1f}%)\n"
        
        return context
    

    
    def _get_ai_response(self, prompt: str, verbose: bool = False, with_reasoning: bool = False) -> str:
        """Get response from selected AI provider.

        with_reasoning=True requests a short, numbered rationale appended to the
        user-facing answer (not chain-of-thought). verbose=True requests more
        detailed fallback output.
        """
        try:
            if self.selected_provider == 'groq' and requests:
                return self._call_groq_api(prompt, include_reasoning=with_reasoning)
            # fallback to rule-based when no Groq key or requests not installed
            return self._get_rule_based_advice(prompt, verbose=verbose, with_reasoning=with_reasoning)

        except Exception as e:
            print(f"AI API Error: {e}")
            return self._get_rule_based_advice(prompt, verbose=verbose, with_reasoning=with_reasoning)
    
    def _call_groq_api(self, prompt: str, include_reasoning: bool = False) -> str:
        """Call Groq API (Fast and Free)"""
        # Prefer using the official Groq Python SDK when available (streaming optional)
        try:
            from groq import Groq
        except Exception:
            Groq = None

        instruction = 'Berikan jawaban singkat dan tindakan yang dapat diambil.'
        if include_reasoning or self.include_reasoning_default:
            instruction += ' Sertakan 2-4 poin singkat yang menjelaskan alasan dan langkah rekomendasi (rangkuman, bukan chain-of-thought).'

        messages = [
            {'role': 'system', 'content': 'Kamu adalah financial advisor yang ramah, ahli keuangan Indonesia, dan memberikan saran praktis dengan bahasa yang mudah dipahami.'},
            {'role': 'user', 'content': instruction + '\n\n' + prompt}
        ]

        # Try SDK first
        if Groq is not None:
            try:
                try:
                    client = Groq(api_key=self.groq_api_key) if self.groq_api_key else Groq()
                except TypeError:
                    # Some SDK versions use env var only
                    client = Groq()

                model_name = self.groq_model
                if '/' not in model_name:
                    model_name = f'openai/{model_name}'

                completion = client.chat.completions.create(
                    model=model_name,
                    messages=messages,
                    temperature=float(self.groq_temperature),
                    max_completion_tokens=int(self.groq_max_tokens),
                    top_p=float(self.groq_top_p),
                    reasoning_effort='medium',
                    stream=False
                )

                # SDK may return an iterator (if streaming) or a response object
                if hasattr(completion, '__iter__') and not isinstance(completion, (str, bytes)):
                    # streamed chunks - concatenate
                    text_parts = []
                    for chunk in completion:
                        try:
                            delta = chunk.choices[0].delta
                            if hasattr(delta, 'content'):
                                text_parts.append(delta.content or '')
                            else:
                                # older SDK shapes
                                text_parts.append(getattr(chunk.choices[0], 'text', '') or '')
                        except Exception:
                            pass
                    return ''.join(text_parts).strip() or self._get_rule_based_advice(prompt, verbose=True, with_reasoning=include_reasoning)
                else:
                    # Non-streaming response
                    try:
                        # Try OpenAI-like structure
                        return completion.choices[0].message.content.strip()
                    except Exception:
                        try:
                            # Other shape
                            return str(completion)
                        except Exception:
                            return self._get_rule_based_advice(prompt, verbose=True, with_reasoning=include_reasoning)

            except Exception as e:
                # SDK call failed; continue to HTTP fallback below
                sdk_err = str(e)
        else:
            sdk_err = 'Groq SDK not installed'

        # If SDK not available or failed, fallback to HTTP approach with configurable endpoint
        base = os.getenv('GROQ_API_BASE', 'https://api.groq.com')
        path = os.getenv('GROQ_API_PATH', '/openai/v1/chat/completions')
        url = base.rstrip('/') + path

        headers = {
            'Authorization': f'Bearer {self.groq_api_key}',
            'Content-Type': 'application/json'
        }

        data = {
            'model': (f'openai/{self.groq_model}' if '/' not in self.groq_model else self.groq_model),
            'messages': messages,
            'max_completion_tokens': int(self.groq_max_tokens),
            'temperature': float(self.groq_temperature),
            'top_p': float(self.groq_top_p),
        }

        if not requests:
            return self._get_rule_based_advice(prompt, verbose=True, with_reasoning=include_reasoning)

        try:
            resp = requests.post(url, headers=headers, json=data, timeout=10)
        except Exception as e:
            return (f"Groq request failed ({sdk_err if 'sdk_err' in locals() else ''}) - network error: {e}. Menggunakan fallback lokal.\n" +
                    self._get_rule_based_advice(prompt, verbose=True, with_reasoning=include_reasoning))

        if resp.status_code == 404:
            snippet = (resp.text or '')[:500]
            return (f"Groq API returned 404 Not Found for URL {url}. Response snippet: {snippet}\n"
                    "Falling back to local rule-based advice.\n" +
                    self._get_rule_based_advice(prompt, verbose=True, with_reasoning=include_reasoning))

        try:
            resp.raise_for_status()
        except Exception as e:
            snippet = (resp.text or '')[:500]
            return (f"Groq API error {resp.status_code}: {e}. Response snippet: {snippet}\n"
                    "Falling back to local rule-based advice.\n" +
                    self._get_rule_based_advice(prompt, verbose=True, with_reasoning=include_reasoning))

        try:
            result = resp.json()
        except Exception:
            body = (resp.text or '')[:1000]
            return (f"Groq API returned non-JSON response (truncated): {body}\n"
                    "Falling back to local rule-based advice.\n" +
                    self._get_rule_based_advice(prompt, verbose=True, with_reasoning=include_reasoning))

        try:
            content = result.get('choices', [])[0].get('message', {}).get('content')
            if content:
                return content.strip()
        except Exception:
            pass

        return self._get_rule_based_advice(prompt, verbose=True, with_reasoning=include_reasoning)
    
    # Removed other provider helpers (Gemini/OpenAI) to enforce Groq-only design
    
    def _get_rule_based_advice(self, prompt: str, verbose: bool = False, with_reasoning: bool = False) -> str:
        """Fallback rule-based advice when no AI API available.

        If verbose=True return multi-point actionable guidance. If
        with_reasoning=True append a short numbered rationale and next steps.
        """

        def short_for(category_hint: str):
            if category_hint == 'makanan':
                return "💡 Tips: Coba meal prep untuk hemat pengeluaran makanan! Masak sendiri bisa hemat 30-50%."
            if category_hint == 'transport':
                return "💡 Tips: Pertimbangkan transportasi umum atau carpooling untuk menghemat biaya transport."
            if category_hint == 'hiburan':
                return "💡 Tips: Set budget hiburan maksimal 10% dari income bulanan ya!"
            return "💡 Tips: Catat pengeluaranmu dan review mingguan untuk menemukan penghematan."

        text = prompt.lower()
        category = None
        if 'makanan' in text:
            category = 'makanan'
        elif 'transport' in text:
            category = 'transport'
        elif 'hiburan' in text or 'entertainment' in text:
            category = 'hiburan'

        if not verbose and not with_reasoning:
            return short_for(category)

        # Rich fallback reasoning: structured output with hypotheses, prioritized actions,
        # estimated savings (conservative ranges), a 4-week experiment plan and KPIs.
        lines = []
        lines.append(short_for(category))

        # Summary / hypothesis
        lines.append('\n� Ringkasan & Hipotesis Penyebab:')
        if category == 'makanan':
            lines.append('- Anda kemungkinan besar menghabiskan banyak untuk makanan karena kombinasi: frekuensi makan di luar, harga per porsi yang relatif tinggi, dan minimnya perencanaan (meal prep).')
        elif category == 'transport':
            lines.append('- Pengeluaran transport bisa tinggi karena rute panjang, penggunaan kendaraan pribadi, atau seringnya perjalanan tidak esensial.')
        else:
            lines.append('- Pengeluaran besar mungkin karena beberapa pengeluaran berulang yang tidak terkontrol atau kebiasaan pembelian impulsif.')

        # Attempt to extract a numeric context (e.g., an example amount) from the prompt
        import re
        amounts = re.findall(r"Rp\s*([0-9\.,]+)", prompt, flags=re.IGNORECASE)
        parsed_amount = None
        if amounts:
            # take the first found number as a reference and normalize
            a = amounts[0].replace('.', '').replace(',', '')
            try:
                parsed_amount = int(a)
            except Exception:
                parsed_amount = None

        # Prioritized actions with conservative estimated savings
        lines.append('\n✅ Rekomendasi Prioritas (urut berdasarkan dampak cepat):')
        if category == 'makanan':
            # Action 1: reduce frequency
            lines.append('1) Kurangi frekuensi makan di luar: target -1 kali/minggu. Estimasi hemat: Rp 50.000 - Rp 150.000/bln (tergantung harga menu).')
            # Action 2: meal prep
            lines.append('2) Meal prep 3x/minggu (siapkan bekal): estimasi hemat: Rp 200.000 - Rp 600.000/bln jika menggantikan 3 makan luar/minggu.')
            # Action 3: pake promo/loyalty
            lines.append('3) Manfaatkan promo, paket hemat, dan loyalty: hemat variatif, estimasi konservatif Rp 30.000 - Rp 150.000/bln.')
            if parsed_amount:
                lines.append(f"(Referensi transaksi yang terdeteksi: Rp {parsed_amount:,})")
        elif category == 'transport':
            lines.append('1) Gunakan transportasi umum/berbagi tumpangan minimal 2x/minggu: estimasi hemat Rp 100.000 - Rp 400.000/bln.')
            lines.append('2) Plan rute & gabungkan trip (kurangi perjalanan tidak esensial): hemat Rp 50.000 - Rp 200.000/bln.')
            lines.append('3) Pertimbangkan kendaraan hemat bahan bakar / sepeda jika memungkinkan: penghematan jangka menengah.')
        else:
            lines.append('1) Audit 2 minggu: catat setiap pengeluaran dan tandai 3 terbesar. Potong 1 pos non-esensial. Estimasi hemat: variatif (Rp 50.000 - Rp 500.000/bln).')
            lines.append('2) Terapkan aturan 24 jam untuk pembelian non-esensial (tunda keputusan).')
            lines.append('3) Atur batas bulanan untuk kategori ini dan otomatisasi transfer ke tabungan.')

        # 4-week experiment plan
        lines.append('\n🗓️ Rencana Eksperimen 4 Minggu:')
        lines.append('Minggu 1: Catat semua pengeluaran makanan/transport selama 7 hari. Ukur frekuensi & rata-rata biaya per kejadian.')
        lines.append('Minggu 2: Terapkan 1 intervensi prioritas (mis. 1x pengurangan makan di luar / meal prep).')
        lines.append('Minggu 3: Tambah intervensi kedua (promo/loyalty atau rute efisien).')
        lines.append('Minggu 4: Review dan kuantifikasi penghematan; tetapkan target bulanan baru.')

        # KPIs & monitoring
        lines.append('\n📈 KPI & Monitoring:')
        lines.append('- KPI 1: Jumlah hari makan di luar per minggu (target: turun X hari).')
        lines.append('- KPI 2: Rata-rata biaya per makan (target: turun Y%).')
        lines.append('- KPI 3: Total penghematan/bln (bandingkan baseline minggu 1 vs minggu 4).')

        # Quick tracking template suggestion
        lines.append('\n🧾 Template Tracking Singkat (copy):')
        lines.append('Tanggal | Kategori | Deskripsi | Jumlah (Rp) | Catatan (mis. alasan pembelian)')

        # Final short rationale summary
        rationale = ('\n\nAlasan singkat dan prioritas:\n'
                     '1. Terapkan langkah berbiaya rendah dan langsung berpengaruh (kurangi frekuensi / meal prep).\n'
                     '2. Ukur dampak dengan eksperimen 4 minggu untuk mengetahui apa yang benar-benar bekerja.\n'
                     '3. Automasi dan batasan membuat perubahan menjadi konsisten dan terukur.')

        result = '\n'.join(lines) + rationale
        return result

# Example usage functions
def get_transaction_insight(amount: float, category: str, description: str, user_financial_data: Dict) -> str:
    """Get AI-powered insight for a transaction"""
    advisor = FinancialAdvisor()
    return advisor.get_transaction_advice(amount, category, description, user_financial_data)

def get_monthly_financial_analysis(user_financial_data: Dict) -> str:
    """Get comprehensive monthly analysis"""
    advisor = FinancialAdvisor()
    return advisor.get_monthly_analysis(user_financial_data)

def get_personalized_budget(monthly_income: float, user_financial_data: Dict) -> str:
    """Get personalized budget recommendations"""
    advisor = FinancialAdvisor()
    return advisor.get_budget_recommendation(monthly_income, user_financial_data)
