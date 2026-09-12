"""
Vercel Serverless API Handler for Flutter Money Record
Provides the same endpoints as the original PHP backend but uses Google Sheets
"""

import base64
import json
import os
import uuid
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler

import gspread
from google.oauth2.service_account import Credentials

# Jakarta timezone (UTC+7)
JAKARTA_TZ = timezone(timedelta(hours=7))

# Google Sheets column names
SHEETS_COLUMNS = [
    "id_history",
    "id_user",
    "type",
    "date",
    "total",
    "details",
    "created_at",
    "updated_at",
]

USER_COLUMNS = ["id_user", "name", "email", "password", "created_at", "updated_at"]


def get_jakarta_time():
    """Get current time in Jakarta timezone (UTC+7)"""
    return datetime.now(JAKARTA_TZ)


def get_sheets_client():
    """Initialize and return Google Sheets client"""
    service_account_key = os.environ.get("GOOGLE_SERVICE_ACCOUNT_KEY")
    sheets_id = os.environ.get("GOOGLE_SHEETS_ID")

    if not service_account_key or not sheets_id:
        raise Exception("Google Sheets not configured")

    # Parse credentials
    decoded_key = base64.b64decode(service_account_key).decode("utf-8")
    credentials_info = json.loads(decoded_key)

    scope = [
        "https://spreadsheets.google.com/feeds",
        "https://www.googleapis.com/auth/drive",
    ]

    credentials = Credentials.from_service_account_info(credentials_info, scopes=scope)
    client = gspread.authorize(credentials)
    return client.open_by_key(sheets_id)


def get_history_sheet():
    """Get the history worksheet"""
    spreadsheet = get_sheets_client()
    try:
        return spreadsheet.worksheet("history")
    except gspread.WorksheetNotFound:
        # Create history sheet if not exists
        sheet = spreadsheet.add_worksheet(
            title="history", rows=1000, cols=len(SHEETS_COLUMNS)
        )
        sheet.append_row(SHEETS_COLUMNS)
        return sheet


def get_user_sheet():
    """Get the user worksheet"""
    spreadsheet = get_sheets_client()
    try:
        return spreadsheet.worksheet("users")
    except gspread.WorksheetNotFound:
        # Create users sheet if not exists
        sheet = spreadsheet.add_worksheet(
            title="users", rows=1000, cols=len(USER_COLUMNS)
        )
        sheet.append_row(USER_COLUMNS)
        return sheet


def row_to_history(row):
    """Convert sheet row to history dict"""
    return {
        "id_history": row.get("id_history", ""),
        "id_user": row.get("id_user", ""),
        "type": row.get("type", ""),
        "date": row.get("date", ""),
        "total": row.get("total", ""),
        "details": row.get("details", ""),
        "created_at": row.get("created_at", ""),
        "updated_at": row.get("updated_at", ""),
    }


def row_to_user(row):
    """Convert sheet row to user dict"""
    return {
        "id_user": row.get("id_user", ""),
        "name": row.get("name", ""),
        "email": row.get("email", ""),
        "password": row.get("password", ""),
        "created_at": row.get("created_at", ""),
        "updated_at": row.get("updated_at", ""),
    }


class handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        """Handle GET requests"""
        self._route_request("GET")

    def do_POST(self):
        """Handle POST requests"""
        self._route_request("POST")

    def _route_request(self, method):
        """Route request to appropriate handler"""
        path = self.path.split("?")[0]

        # History endpoints
        if path == "/api/history/analysis.php":
            self._handle_analysis()
        elif path == "/api/history/add.php":
            self._handle_add_history()
        elif path == "/api/history/update.php":
            self._handle_update_history()
        elif path == "/api/history/delete.php":
            self._handle_delete_history()
        elif path == "/api/history/income_outcome.php":
            self._handle_income_outcome()
        elif path == "/api/history/income_outcome_search.php":
            self._handle_income_outcome_search()
        elif path == "/api/history/history.php":
            self._handle_history()
        elif path == "/api/history/history_search.php":
            self._handle_history_search()
        elif path == "/api/history/where_date.php":
            self._handle_where_date()
        elif path == "/api/history/detail.php":
            self._handle_detail()

        # User endpoints
        elif path == "/api/user/login.php":
            self._handle_login()
        elif path == "/api/user/register.php":
            self._handle_register()
        else:
            self._send_error_response(404, "Endpoint not found")

    def _parse_body(self):
        """Parse request body"""
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            return {}
        body = self.rfile.read(content_length).decode("utf-8")
        try:
            return json.loads(body)
        except:
            # Try form data
            import urllib.parse

            return dict(urllib.parse.parse_qsl(body))

    def _send_json_response(self, data, status=200):
        """Send JSON response"""
        self.send_response(status)
        self.send_header("Content-type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode("utf-8"))

    def _send_error_response(self, code, message):
        """Send error response"""
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

    # ==================== HISTORY HANDLERS ====================

    def _handle_analysis(self):
        """GET /api/history/analysis.php - Get analysis data for dashboard"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            today = data.get("today", get_jakarta_time().strftime("%Y-%m-%d"))

            if not id_user:
                self._send_error_response(400, "id_user required")
                return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            # Filter by user
            user_records = [r for r in records if r.get("id_user") == id_user]

            # Calculate today's expense
            today_expense = 0
            yesterday_expense = 0
            week_expenses = [0] * 7
            month_income = 0
            month_outcome = 0

            today_date = datetime.strptime(today, "%Y-%m-%d").date()
            yesterday_date = today_date - timedelta(days=1)
            week_start = today_date - timedelta(days=today_date.weekday())
            month_start = today_date.replace(day=1)

            for record in user_records:
                try:
                    record_date = datetime.strptime(
                        record.get("date", ""), "%Y-%m-%d"
                    ).date()
                    total = float(record.get("total", 0))
                    record_type = record.get("type", "")

                    if record_type == "Pengeluaran":
                        # Today
                        if record_date == today_date:
                            today_expense += total
                        # Yesterday
                        elif record_date == yesterday_date:
                            yesterday_expense += total
                        # This week
                        if week_start <= record_date <= today_date:
                            day_idx = record_date.weekday()
                            week_expenses[day_idx] += total
                        # This month
                        if record_date >= month_start:
                            month_outcome += total
                    elif record_type == "Pemasukan":
                        if record_date >= month_start:
                            month_income += total
                except:
                    continue

            # Calculate today percent vs yesterday
            if yesterday_expense > 0:
                today_percent = f"{((today_expense - yesterday_expense) / yesterday_expense * 100):.1f}%"
            else:
                today_percent = "0%"

            # Week text labels
            week_text = []
            for i in range(7):
                day = week_start + timedelta(days=i)
                week_text.append(day.strftime("%a"))

            response = {
                "success": True,
                "data": {
                    "today": today_expense,
                    "today_percent": today_percent,
                    "week": week_expenses,
                    "week_text": week_text,
                    "month": {
                        "income": month_income,
                        "outcome": month_outcome,
                    },
                },
            }
            self._send_json_response(response)

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_add_history(self):
        """POST /api/history/add.php - Add new history record"""
        try:
            data = self._parse_body()
            required = ["id_user", "date", "type", "details", "total"]
            for field in required:
                if not data.get(field):
                    self._send_error_response(400, f"{field} required")
                    return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            # Check if history for this date and type already exists
            for record in records:
                if (
                    record.get("id_user") == data["id_user"]
                    and record.get("date") == data["date"]
                    and record.get("type") == data["type"]
                ):
                    self._send_json_response({"success": False, "message": "date"})
                    return

            # Create new record
            now = get_jakarta_time().isoformat()
            new_id = str(uuid.uuid4())[:8]
            new_row = [
                new_id,
                data["id_user"],
                data["type"],
                data["date"],
                data["total"],
                data["details"],
                now,
                now,
            ]
            sheet.append_row(new_row)

            self._send_json_response({"success": True})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_update_history(self):
        """POST /api/history/update.php - Update history record"""
        try:
            data = self._parse_body()
            required = ["id_history", "id_user", "date", "type", "details", "total"]
            for field in required:
                if not data.get(field):
                    self._send_error_response(400, f"{field} required")
                    return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            # Check for date conflict (excluding current record)
            for i, record in enumerate(records):
                if (
                    record.get("id_user") == data["id_user"]
                    and record.get("date") == data["date"]
                    and record.get("type") == data["type"]
                    and record.get("id_history") != data["id_history"]
                ):
                    self._send_json_response({"success": False, "message": "date"})
                    return

            # Find and update record
            for i, record in enumerate(records):
                if record.get("id_history") == data["id_history"]:
                    now = get_jakarta_time().isoformat()
                    row_num = i + 2  # +2 because header is row 1, 0-indexed
                    sheet.update(
                        f"A{row_num}:H{row_num}",
                        [
                            [
                                data["id_history"],
                                data["id_user"],
                                data["type"],
                                data["date"],
                                data["total"],
                                data["details"],
                                record.get("created_at", now),
                                now,
                            ]
                        ],
                    )
                    self._send_json_response({"success": True})
                    return

            self._send_json_response({"success": False, "message": "not found"})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_delete_history(self):
        """POST /api/history/delete.php - Delete history record"""
        try:
            data = self._parse_body()
            id_history = data.get("id_history")

            if not id_history:
                self._send_error_response(400, "id_history required")
                return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            for i, record in enumerate(records):
                if record.get("id_history") == id_history:
                    row_num = i + 2
                    sheet.delete_rows(row_num)
                    self._send_json_response({"success": True})
                    return

            self._send_json_response({"success": False, "message": "not found"})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_income_outcome(self):
        """POST /api/history/income_outcome.php - Get income/outcome list"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            type_filter = data.get("type")

            if not id_user or not type_filter:
                self._send_error_response(400, "id_user and type required")
                return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            filtered = [
                row_to_history(r)
                for r in records
                if r.get("id_user") == id_user and r.get("type") == type_filter
            ]

            # Sort by date descending
            filtered.sort(key=lambda x: x["date"], reverse=True)

            self._send_json_response({"success": True, "data": filtered})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_income_outcome_search(self):
        """POST /api/history/income_outcome_search.php - Search income/outcome by date"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            type_filter = data.get("type")
            date = data.get("date")

            if not all([id_user, type_filter, date]):
                self._send_error_response(400, "id_user, type, and date required")
                return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            filtered = [
                row_to_history(r)
                for r in records
                if r.get("id_user") == id_user
                and r.get("type") == type_filter
                and r.get("date") == date
            ]

            self._send_json_response({"success": True, "data": filtered})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_history(self):
        """POST /api/history/history.php - Get all history for user"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")

            if not id_user:
                self._send_error_response(400, "id_user required")
                return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            filtered = [
                row_to_history(r) for r in records if r.get("id_user") == id_user
            ]

            # Sort by date descending
            filtered.sort(key=lambda x: x["date"], reverse=True)

            self._send_json_response({"success": True, "data": filtered})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_history_search(self):
        """POST /api/history/history_search.php - Search history by date"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            date = data.get("date")

            if not id_user or not date:
                self._send_error_response(400, "id_user and date required")
                return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            filtered = [
                row_to_history(r)
                for r in records
                if r.get("id_user") == id_user and r.get("date") == date
            ]

            self._send_json_response({"success": True, "data": filtered})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_where_date(self):
        """POST /api/history/where_date.php - Get history for specific date"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            date = data.get("date")

            if not id_user or not date:
                self._send_error_response(400, "id_user and date required")
                return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            for record in records:
                if record.get("id_user") == id_user and record.get("date") == date:
                    self._send_json_response(
                        {"success": True, "data": row_to_history(record)}
                    )
                    return

            self._send_json_response({"success": False, "message": "not found"})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_detail(self):
        """POST /api/history/detail.php - Get detail for date and type"""
        try:
            data = self._parse_body()
            id_user = data.get("id_user")
            date = data.get("date")
            type_filter = data.get("type")

            if not all([id_user, date, type_filter]):
                self._send_error_response(400, "id_user, date, and type required")
                return

            sheet = get_history_sheet()
            records = sheet.get_all_records()

            for record in records:
                if (
                    record.get("id_user") == id_user
                    and record.get("date") == date
                    and record.get("type") == type_filter
                ):
                    self._send_json_response(
                        {"success": True, "data": row_to_history(record)}
                    )
                    return

            self._send_json_response({"success": False, "message": "not found"})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    # ==================== USER HANDLERS ====================

    def _handle_login(self):
        """POST /api/user/login.php - User login"""
        try:
            data = self._parse_body()
            email = data.get("email")
            password = data.get("password")

            if not email or not password:
                self._send_error_response(400, "email and password required")
                return

            sheet = get_user_sheet()
            records = sheet.get_all_records()

            for record in records:
                if record.get("email") == email and record.get("password") == password:
                    user_data = row_to_user(record)
                    self._send_json_response({"success": True, "data": user_data})
                    return

            self._send_json_response(
                {"success": False, "message": "invalid credentials"}
            )

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")

    def _handle_register(self):
        """POST /api/user/register.php - User registration"""
        try:
            data = self._parse_body()
            name = data.get("name")
            email = data.get("email")
            password = data.get("password")

            if not all([name, email, password]):
                self._send_error_response(400, "name, email, and password required")
                return

            sheet = get_user_sheet()
            records = sheet.get_all_records()

            # Check if email exists
            for record in records:
                if record.get("email") == email:
                    self._send_json_response({"success": False, "message": "email"})
                    return

            # Create new user
            now = get_jakarta_time().isoformat()
            new_id = str(uuid.uuid4())[:8]
            new_row = [
                new_id,
                name,
                email,
                password,
                now,
                now,
            ]
            sheet.append_row(new_row)

            user_data = {
                "id_user": new_id,
                "name": name,
                "email": email,
                "password": password,
                "created_at": now,
                "updated_at": now,
            }
            self._send_json_response({"success": True, "data": user_data})

        except Exception as e:
            self._send_error_response(500, f"Error: {str(e)}")
