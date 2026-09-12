"""
AI Financial Advisor for Flutter Money Record
Provides AI-powered financial insights and recommendations
"""

import base64
import json
import os
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler

import gspread
from google.oauth2.service_account import Credentials

# Jakarta timezone (UTC+7)
JAKARTA_TZ = timezone(timedelta(hours=7))


def get_jakarta_time():
    """Get current time in Jakarta timezone (UTC+7)"""
    return datetime.now(JAKARTA_TZ)


def get_sheets_client():
    """Initialize and return Google Sheets client"""
    service_account_key = os.environ.get("GOOGLE_SERVICE_ACCOUNT_KEY")
    sheets_id = os.environ.get("GOOGLE_SHEETS_ID")

    if not service_account_key or not sheets_id:
        raise Exception("Google Sheets not configured")

    decoded_key = base64.b64decode(service_account_key).decode("utf-8")
    credentials_info = json.loads(decoded_key)

    scope = [
        "https://spreadsheets.google.com/feeds",
        "https://www.googleapis.com/auth/drive",
    ]

    credentials = Credentials.from_service_account_info(credentials_info, scopes=scope)
    client = gspread.authorize(credentials)
    return client.open_by_key(sheets_id)


def get_user_financial_data(id_user):
    """Get user's financial data from Google Sheets"""
    try:
        spreadsheet = get_sheets_client()
        sheet = spreadsheet.worksheet("history")
        records = sheet.get_all_records()

        user_records = [r for r in records if r.get("id_user") == id_user]

        total_income = 0
        total_expense = 0
        categories = {}
        monthly_data = {}
        recent_transactions = []

        for record in user_records:
            try:
                kategori = record.get("type", "").lower()
                jumlah = float(record.get("total", 0))
                tanggal = record.get("date", "")
                details = record.get("details", "")

                if kategori and jumlah > 0:
                    if kategori == "pemasukan":
                        total_income += jumlah
                        cat_key = f"income_{details}" if details else "income_lainnya"
                        categories[cat_key] = categories.get(cat_key, 0) + jumlah
                    else:
                        total_expense += jumlah
                        cat_key = details if details else "pengeluaran_lainnya"
                        categories[cat_key] = categories.get(cat_key, 0) + jumlah

                    if tanggal:
                        month = tanggal[:7]
                        if kategori == "pemasukan":
                            monthly_data[month] = monthly_data.get(
                                month, {"income": 0, "expense": 0}
                            )
                            monthly_data[month]["income"] += jumlah
                        else:
                            monthly_data[month] = monthly_data.get(
                                month, {"income": 0, "expense": 0}
                            )
                            monthly_data[month]["expense"] += jumlah

                    recent_transactions.append(
                        {
                            "date": tanggal,
                            "type": kategori,
                            "amount": jumlah,
                            "details": details,
                        }
                    )
            except:
                continue

        recent_transactions.sort(key=lambda x: x["date"], reverse=True)
        recent_transactions = recent_transactions[:10]

        balance = total_income - total_expense

        return {
            "total_income": total_income,
            "total_expense": total_expense,
            "balance": balance,
            "categories": categories,
            "monthly_data": monthly_data,
            "recent_transactions": recent_transactions,
            "transaction_count": len(user_records),
        }
    except Exception as e:
        return {
            "total_income": 0,
            "total_expense": 0,
            "balance": 0,
            "categories": {},
            "monthly_data": {},
            "recent_transactions": [],
            "transaction_count": 0,
            "error": str(e),
        }


def get_rule_based_advice(financial_data, query_type):
    """Generate rule-based financial advice"""
    balance = financial_data.get("balance", 0)
    total_income = financial_data.get("total_income", 0)
    total_expense = financial_data.get("total_expense", 0)
    categories = financial_data.get("categories", {})

    if query_type == "transaction":
        # Find highest expense category
        expense_cats = {
            k: v for k, v in categories.items() if not k.startswith("income_")
        }
        if expense_cats:
            top_cat = max(expense_cats, key=expense_cats.get)
            top_amount = expense_cats[top_cat]
            return f"Pengeluaran terbesar Anda adalah {top_cat} sebesar Rp {top_amount:,.0f}. Coba kurangi pengeluaran di kategori ini."

    elif query_type == "monthly":
        if balance < 0:
            return f"Saldo Anda negatif (Rp {balance:,.0f}). Segera kurangi pengeluaran dan cari sumber pendapatan tambahan."
        elif balance < total_income * 0.2:
            return f"Tabungan Anda hanya Rp {balance:,.0f} ({balance / total_income * 100:.1f}% dari pemasukan). Targetkan minimal 20% untuk tabungan."
        else:
            return f"Bagus! Anda menabung Rp {balance:,.0f} ({balance / total_income * 100:.1f}% dari pemasukan). Pertahankan!"

    elif query_type == "budget":
        income = financial_data.get("monthly_income", total_income)
        if income > 0:
            recommended_saving = income * 0.2
            recommended_expense = income * 0.5
            return (
                f"Dengan pemasukan Rp {income:,.0f}/bulan:\n"
                f"- Tabungan minimal: Rp {recommended_saving:,.0f} (20%)\n"
                f"- Kebutuhan: Rp {recommended_expense:,.0f} (50%)\n"
                f"- Keinginan: Rp {income * 0.3:,.0f} (30%)"
            )
        return "Masukkan pemasukan bulanan untuk rekomendasi budget."

    return "Tidak ada saran spesifik saat ini."


class AIAdvisorHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        path = self.path.split("?")[0]

        if path == "/api/ai/transaction_advice":
            self._handle_transaction_advice()
        elif path == "/api/ai/monthly_analysis":
            self._handle_monthly_analysis()
        elif path == "/api/ai/budget_recommendation":
            self._handle_budget_recommendation()
        elif path == "/api/ai/budget_check":
            self._handle_budget_check()
        elif path == "/api/ai/daily_plan":
            self._handle_daily_plan()
        else:
            self._send_error_response(404, "AI endpoint not found")

    def _parse_body(self):
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            return {}
        body = self.rfile.read(content_length).decode("utf-8")
        try:
            return json.loads(body)
        except:
            import urllib.parse

            return dict(urllib.parse.parse_qsl(body))

    def _send_json_response(self, data, status=200):
        self.send_response(status)
        self.send_header("Content-type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

    def _send_error_response(self, code, message):
        self.send_response(code)
        self.send_header("Content-type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        error_response = {
            "success": False,
            "message": message,
            "timestamp": get_jakarta_time().isoformat(),
        }
        self.wfile.write(json.dumps(error_response).encode("utf-8"))

    def _handle_transaction_advice(self):
        """Get AI advice for a specific transaction"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            amount = data.get("amount")
            category = data.get("category")
            description = data.get("description")

            if not all([id_user, amount, category]):
                self._send_error_response(400, "id_user, amount, category required")
                return

            financial_data = get_user_financial_data(id_user)
            advice = get_rule_based_advice(financial_data, "transaction")

            self._send_json_response(
                {
                    "success": True,
                    "advice": advice,
                    "transaction": {
                        "amount": amount,
                        "category": category,
                        "description": description,
                    },
                }
            )
        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_monthly_analysis(self):
        """Get monthly financial analysis"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")

            if not id_user:
                self._send_error_response(400, "id_user required")
                return

            financial_data = get_user_financial_data(id_user)
            advice = get_rule_based_advice(financial_data, "monthly")

            self._send_json_response(
                {
                    "success": True,
                    "analysis": {
                        "total_income": financial_data["total_income"],
                        "total_expense": financial_data["total_expense"],
                        "balance": financial_data["balance"],
                        "categories": financial_data["categories"],
                        "monthly_data": financial_data["monthly_data"],
                    },
                    "advice": advice,
                }
            )
        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_budget_recommendation(self):
        """Get budget recommendation based on income"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            monthly_income = data.get("monthly_income")

            if not id_user or not monthly_income:
                self._send_error_response(400, "id_user and monthly_income required")
                return

            financial_data = get_user_financial_data(id_user)
            financial_data["monthly_income"] = float(monthly_income)
            advice = get_rule_based_advice(financial_data, "budget")

            self._send_json_response(
                {
                    "success": True,
                    "monthly_income": monthly_income,
                    "recommendation": advice,
                }
            )
        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_budget_check(self):
        """Check if budget is feasible for given days"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            amount = data.get("amount")
            days = data.get("days", 30)

            if not all([id_user, amount]):
                self._send_error_response(400, "id_user and amount required")
                return

            financial_data = get_user_financial_data(id_user)
            daily_budget = float(amount) / int(days)
            avg_daily_expense = (
                financial_data["total_expense"] / 30
                if financial_data["total_expense"] > 0
                else 0
            )

            if daily_budget >= avg_daily_expense * 1.2:
                feasibility = "Sangat Aman"
                message = f"Budget harian Rp {daily_budget:,.0f} cukup untuk pengeluaran rata-rata Rp {avg_daily_expense:,.0f}/hari."
            elif daily_budget >= avg_daily_expense:
                feasibility = "Aman"
                message = f"Budget harian Rp {daily_budget:,.0f} mencukupi untuk pengeluaran rata-rata Rp {avg_daily_expense:,.0f}/hari."
            else:
                feasibility = "Berisiko"
                message = f"Budget harian Rp {daily_budget:,.0f} KURANG dari pengeluaran rata-rata Rp {avg_daily_expense:,.0f}/hari."

            self._send_json_response(
                {
                    "success": True,
                    "daily_budget": daily_budget,
                    "avg_daily_expense": avg_daily_expense,
                    "feasibility": feasibility,
                    "message": message,
                    "days": days,
                }
            )
        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_daily_plan(self):
        """Get daily spending plan"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            daily_budget = data.get("daily_budget")

            if not all([id_user, daily_budget]):
                self._send_error_response(400, "id_user and daily_budget required")
                return

            financial_data = get_user_financial_data(id_user)
            daily_budget = float(daily_budget)

            # Simple allocation
            meals = daily_budget * 0.4
            transport = daily_budget * 0.2
            others = daily_budget * 0.3
            emergency = daily_budget * 0.1

            self._send_json_response(
                {
                    "success": True,
                    "daily_budget": daily_budget,
                    "plan": {
                        "makanan": meals,
                        "transport": transport,
                        "lainnya": others,
                        "darurat": emergency,
                    },
                    "message": f"Rencana harian untuk budget Rp {daily_budget:,.0f}: Makanan Rp {meals:,.0f}, Transport Rp {transport:,.0f}, Lainnya Rp {others:,.0f}, Darurat Rp {emergency:,.0f}",
                }
            )
        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")
