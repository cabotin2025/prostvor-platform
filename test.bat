@echo off
curl -X POST http://localhost:8000/api/auth/register.php ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"test2@example.com\",\"password\":\"test123\",\"nickname\":\"TestUser\",\"name\":\"\u0418\u0432\u0430\u043d\",\"last_name\":\"\u0418\u0432\u0430\u043d\u043e\u0432\"}"
pause