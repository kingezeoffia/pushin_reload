# Pushin Reload Authentication System

## 🎯 Overview

Complete authentication system with email/password, Google OAuth, and Apple Sign In support. Built with security best practices and modular architecture.

## 📁 Files Created

- **`auth.js`** - Core authentication module with all business logic
- **`authRoutes.js`** - Express routes for authentication endpoints
- **`test-auth.js`** - Test suite for authentication functionality
- **`server.js`** - Updated to use modular authentication system

## 🔐 Authentication Features

### Supported Methods
- ✅ Email + Password (bcrypt hashing)
- ✅ Google OAuth (ID token verification)
- ✅ Apple Sign In (identity token decoding)
- ✅ JWT access tokens (15-minute expiry)
- ✅ JWT refresh tokens (7-day expiry, stored in DB)
- ✅ Account linking (same email across providers)

### Security Features
- Password hashing with bcrypt (12 salt rounds)
- JWT tokens with proper secrets
- Refresh token rotation
- Secure token storage in database
- No sensitive data in logs
- Input validation and sanitization

## 🗄️ Database Schema

```sql
-- Users table
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255),           -- NULL for OAuth-only accounts
  apple_id VARCHAR(255) UNIQUE,         -- NULL for non-Apple users
  google_id VARCHAR(255) UNIQUE,        -- NULL for non-Google users
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Refresh tokens table
CREATE TABLE refresh_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  token VARCHAR(500) UNIQUE NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🚀 API Endpoints

### Authentication Routes

All routes are prefixed with `/api/auth`

#### POST `/api/auth/register`
Register a new user with email and password.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123!"
}
```

**Response (201):**
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": 123,
      "email": "user@example.com",
      "createdAt": "2024-01-01T00:00:00.000Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

#### POST `/api/auth/login`
Login with email and password.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123!"
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "id": 123,
      "email": "user@example.com",
      "createdAt": "2024-01-01T00:00:00.000Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

#### POST `/api/auth/google`
Authenticate with Google OAuth.

**Request:**
```json
{
  "idToken": "eyJhbGciOiJSUzI1NiIs..."
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Google authentication successful",
  "data": {
    "user": {
      "id": 123,
      "email": "user@example.com",
      "createdAt": "2024-01-01T00:00:00.000Z"
    },
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

#### POST `/api/auth/apple`
Authenticate with Apple Sign In.

**Request:**
```json
{
  "identityToken": "eyJhbGciOiJSUzI1NiIs...",
  "authorizationCode": "optional-code",
  "user": {
    "email": "user@example.com"
  }
}
```

#### POST `/api/auth/refresh`
Refresh access token using refresh token.

**Request:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response (200):**
```json
{
  "success": true,
  "message": "Token refreshed successfully",
  "data": {
    "accessToken": "new-access-token",
    "refreshToken": "new-refresh-token"
  }
}
```

#### GET `/api/auth/me`
Get current user profile (requires authentication).

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 123,
      "email": "user@example.com",
      "createdAt": "2024-01-01T00:00:00.000Z"
    }
  }
}
```

#### POST `/api/auth/logout`
Logout user and invalidate refresh tokens (requires authentication).

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200):**
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

## 🔧 Usage Examples

### Using with Flutter/Dart (HTTP Package)

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

// Register user
Future<void> registerUser(String email, String password) async {
  final response = await http.post(
    Uri.parse('https://your-api.com/api/auth/register'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // Store tokens securely
    await secureStorage.write(key: 'accessToken', value: data['data']['accessToken']);
    await secureStorage.write(key: 'refreshToken', value: data['data']['refreshToken']);
  }
}

// Login user
Future<void> loginUser(String email, String password) async {
  final response = await http.post(
    Uri.parse('https://your-api.com/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  // Handle response similar to register
}

// Authenticated request
Future<void> getUserProfile() async {
  final accessToken = await secureStorage.read(key: 'accessToken');

  final response = await http.get(
    Uri.parse('https://your-api.com/api/auth/me'),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print('User: ${data['data']['user']}');
  } else if (response.statusCode == 401) {
    // Token expired, try refresh
    await refreshToken();
  }
}

// Refresh token
Future<void> refreshToken() async {
  final refreshToken = await secureStorage.read(key: 'refreshToken');

  final response = await http.post(
    Uri.parse('https://your-api.com/api/auth/refresh'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'refreshToken': refreshToken,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    // Update stored tokens
    await secureStorage.write(key: 'accessToken', value: data['data']['accessToken']);
    await secureStorage.write(key: 'refreshToken', value: data['data']['refreshToken']);
  }
}
```

## 🧪 Testing

### Run Authentication Tests

```bash
cd backend
npm run test-auth
```

This will test:
- Password hashing/verification
- JWT token generation/verification
- Database connectivity
- User registration/login flow
- Token refresh functionality

### Manual Testing with cURL

```bash
# Register user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Login user
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Get user profile (replace TOKEN with actual access token)
curl -X GET http://localhost:3000/api/auth/me \
  -H "Authorization: Bearer TOKEN"
```

## 🔒 Security Considerations

1. **Environment Variables**: Set strong secrets in production
   ```bash
   JWT_SECRET=your-super-secure-jwt-secret-here
   JWT_REFRESH_SECRET=your-super-secure-refresh-secret-here
   ```

2. **HTTPS Only**: Always use HTTPS in production

3. **Token Storage**: Store tokens securely on client side
   - Use secure storage (Keychain/iOS, Keystore/Android)
   - Never store in plain text or localStorage

4. **Password Policy**: Consider implementing client-side validation
   - Minimum length (8+ characters)
   - Mix of uppercase, lowercase, numbers, symbols

5. **Rate Limiting**: Consider adding rate limiting to prevent brute force attacks

## 🚀 Deployment

The authentication system is ready for deployment to Railway:

1. **Database**: Tables are auto-created by `create_all_tables.js`
2. **Environment**: Set `DATABASE_URL`, `JWT_SECRET`, `JWT_REFRESH_SECRET`
3. **SSL**: Automatically configured for Railway connections

## 📋 Error Codes

| Code | Description |
|------|-------------|
| `MISSING_FIELDS` | Required fields missing |
| `USER_EXISTS` | User already exists |
| `INVALID_CREDENTIALS` | Wrong email/password |
| `OAUTH_ONLY` | Account requires OAuth login |
| `TOKEN_MISSING` | Authorization header missing |
| `TOKEN_INVALID` | Invalid/expired access token |
| `MISSING_TOKEN` | OAuth token missing |
| `INVALID_GOOGLE_TOKEN` | Invalid Google ID token |
| `INVALID_APPLE_TOKEN` | Invalid Apple identity token |
| `MISSING_EMAIL` | Email required for Apple Sign In |
| `MISSING_REFRESH_TOKEN` | Refresh token missing |
| `INVALID_REFRESH_TOKEN` | Invalid/expired refresh token |
| `USER_NOT_FOUND` | User not found |
| `REGISTRATION_ERROR` | Registration failed |
| `LOGIN_ERROR` | Login failed |
| `GOOGLE_AUTH_ERROR` | Google authentication failed |
| `APPLE_AUTH_ERROR` | Apple authentication failed |
| `REFRESH_ERROR` | Token refresh failed |
| `GET_USER_ERROR` | Failed to get user data |
| `LOGOUT_ERROR` | Logout failed |

---

## 🎉 Implementation Complete!

Your authentication system supports:
- ✅ Email/password registration and login
- ✅ Google OAuth integration
- ✅ Apple Sign In integration
- ✅ JWT token management with refresh
- ✅ Secure password hashing
- ✅ Account linking across providers
- ✅ Modular, maintainable code structure
- ✅ Comprehensive error handling
- ✅ Ready for production deployment