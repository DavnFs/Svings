import json
import os
import base64
from datetime import datetime, timezone, timedelta
from http.server import BaseHTTPRequestHandler
import gspread
from google.oauth2.service_account import Credentials

# Jakarta timezone (UTC+7)
JAKARTA_TZ = timezone(timedelta(hours=7))

# Default saving target
DEFAULT_SAVING_TARGET = 1_000_000  # Rp 1 juta per bulan


def get_jakarta_time():
    """Get current time in Jakarta timezone (UTC+7)"""
    return datetime.now(JAKARTA_TZ)


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        """Get expense report"""
        try:
            report_data = self._generate_report()
            self._send_json_response(report_data)
        except Exception as e:
            self._send_error_response(500, f"Error generating report: {str(e)}")

    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def _generate_report(self):
        """Generate expense report from Google Sheets"""
        try:
            service_account_key = os.environ.get('GOOGLE_SERVICE_ACCOUNT_KEY')
            sheets_id = os.environ.get('GOOGLE_SHEETS_ID')

            if not service_account_key or not sheets_id:
                return {"status": "error", "message": "Google Sheets not configured"}

            # Parse credentials
            decoded_key = base64.b64decode(service_account_key).decode('utf-8')
            credentials_info = json.loads(decoded_key)

            scope = [
                "https://spreadsheets.google.com/feeds",
                "https://www.googleapis.com/auth/drive"
            ]

            credentials = Credentials.from_service_account_info(credentials_info, scopes=scope)
            client = gspread.authorize(credentials)
            sheet = client.open_by_key(sheets_id).sheet1
            data = sheet.get_all_records()

            # Generate summary
            summary = {}
            total_expense = 0
            total_income = 0
            category_count = {}
            monthly_data = {}

            for row in data:
                kategori = row.get('Kategori', '').lower()
                jumlah = int(row.get('Jumlah', 0)) if row.get('Jumlah') else 0
                tanggal = row.get('Tanggal', '')

                if kategori and jumlah != 0:
                    # Separate income and expenses
                    if jumlah > 0:
                        total_income += jumlah
                        summary[f"income_{kategori}"] = summary.get(f"income_{kategori}", 0) + jumlah
                    else:
                        expense_amount = abs(jumlah)
                        total_expense += expense_amount
                        summary[kategori] = summary.get(kategori, 0) + expense_amount

                    category_count[kategori] = category_count.get(kategori, 0) + 1

                    # Monthly summary
                    if tanggal:
                        try:
                            month = tanggal[:7]  # YYYY-MM
                            if jumlah > 0:
                                monthly_data[month] = monthly_data.get(month, {"income": 0, "expense": 0})
                                monthly_data[month]["income"] += jumlah
                            else:
                                monthly_data[month] = monthly_data.get(month, {"income": 0, "expense": 0})
                                monthly_data[month]["expense"] += abs(jumlah)
                        except:
                            pass

            # Get recent transactions (last 10)
            recent_transactions = data[-10:] if len(data) > 10 else data
            recent_transactions.reverse()

            # Calculate balance
            balance = total_income - total_expense

            # Calculate advice
            advice = {}
            available_after_saving = balance - DEFAULT_SAVING_TARGET
            if available_after_saving < 0:
                advice_message = (
                    f"Saldo kamu saat ini Rp{balance:,}. "
                    f"Kamu belum bisa menyisihkan Rp{DEFAULT_SAVING_TARGET:,} untuk tabungan. "
                    f"Coba kurangi pengeluaran agar bisa nabung minimal Rp{DEFAULT_SAVING_TARGET:,}."
                )
            else:
                advice_message = (
                    f"Saldo kamu saat ini Rp{balance:,}. "
                    f"Setelah menyisihkan Rp{DEFAULT_SAVING_TARGET:,} untuk tabungan, "
                    f"kamu masih punya Rp{available_after_saving:,} yang bisa digunakan."
                )

            advice["message"] = advice_message
            advice["balance"] = balance
            advice["saving_target"] = DEFAULT_SAVING_TARGET
            advice["available_after_saving"] = max(0, available_after_saving)

            return {
                "status": "success",
                "timestamp": get_jakarta_time().isoformat(),
                "timezone": "WIB (UTC+7)",
                "summary": {
                    "total_income": total_income,
                    "total_expense": total_expense,
                    "balance": balance,
                    "total_transactions": len(data),
                    "categories": summary,
                    "category_counts": category_count,
                    "monthly_breakdown": monthly_data
                },
                "recent_transactions": recent_transactions,
                "advice": advice,
                "message": f"Report generated with {len(data)} transactions at {get_jakarta_time().strftime('%d/%m/%Y %H:%M')} WIB"
            }

        except Exception as e:
            return {"status": "error", "message": f"Error: {str(e)}"}

    def _send_json_response(self, data):
        """Send JSON response"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))

    def _send_error_response(self, code, message):
        """Send error response"""
        self.send_response(code)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        error_response = {
            "status": "error",
            "message": message,
            "timestamp": get_jakarta_time().isoformat(),
            "timezone": "WIB (UTC+7)"
        }
        self.wfile.write(json.dumps(error_response).encode())
