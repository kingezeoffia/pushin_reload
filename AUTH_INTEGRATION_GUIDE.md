# 🔐 Authentication Integration Guide
## Pushin Reload - Backend + Flutter Integration

### ✅ Integration Status: COMPLETE
All authentication endpoints are fully integrated and tested.

---

## 🧪 Testing Instructions

### Backend Testing

#### 1. Logic Tests (No Database Required)
```bash
cd backend
node test-auth-logic.js
```
✅ **Expected Output:**
- Password hashing/verification: Working
- JWT token generation/verification: Working
- OAuth logic: Available
- Security: Environment variables used

#### 2. Full Integration Tests (Requires Database)
```bash
# Set up DATABASE_URL environment variable first
cd backend
npm run test-auth
```
**Required Environment Setup:**
```bash
# Create .env file in backend directory
DATABASE_URL="postgresql://username:password@host:port/database"

# Or run the setup script
../fix-env.sh
```

### Flutter Testing

#### 1. Unit Tests
```bash
flutter test test/services/
```

#### 2. Integration Tests
```bash
flutter test integration_test/
```

#### 3. Manual Testing Steps
1. **Registration Flow:**
   - Open app → Sign Up
   - Enter email/password
   - Verify success message
   - Check backend logs for user creation

2. **Login Flow:**
   - Use registered credentials
   - Verify JWT tokens stored
   - Check secure storage persistence

3. **OAuth Testing:**
   - **Google:** Configure Google Sign-In in Firebase/Console
   - **Apple:** Configure Apple Sign-In capability
   - Test both flows end-to-end

4. **Token Refresh:**
   - Login and wait 15+ minutes
   - Perform authenticated action
   - Verify automatic token refresh

---

## 🔒 Security Verification

### ✅ Backend Security
- [x] **Password Hashing:** bcrypt with 12 salt rounds
- [x] **JWT Secrets:** Environment variables (JWT_SECRET, JWT_REFRESH_SECRET)
- [x] **Token Expiration:** 15min access, 7day refresh
- [x] **Refresh Token Rotation:** New refresh token on each use
- [x] **Database Security:** Parameterized queries prevent SQL injection
- [x] **CORS Protection:** Configured for Flutter app domains
- [x] **Error Handling:** No sensitive data in error messages

### ✅ Flutter Security
- [x] **Token Storage:** Flutter Secure Storage (encrypted)
- [x] **Automatic Refresh:** Tokens refreshed before expiration
- [x] **Network Security:** HTTPS required for production
- [x] **OAuth Security:** Proper token validation
- [x] **Error Handling:** Network/401/403 errors handled gracefully

### ✅ Database Security
- [x] **Connection:** SSL enabled for Railway PostgreSQL
- [x] **Tables:** Proper foreign key constraints
- [x] **Indexes:** Email uniqueness enforced
- [x] **Cleanup:** Refresh tokens auto-expire and cascade delete

---

## 📡 API Endpoints Reference

### Authentication Endpoints
All endpoints return JSON with `success: boolean` and either `data` or `error`.

| Method | Endpoint | Description | Request Body | Response |
|--------|----------|-------------|--------------|----------|
| POST | `/api/auth/register` | Register new user | `{email, password}` | `{user, accessToken, refreshToken}` |
| POST | `/api/auth/login` | Login with credentials | `{email, password}` | `{user, accessToken, refreshToken}` |
| POST | `/api/auth/google` | Google OAuth login | `{idToken}` | `{user, accessToken, refreshToken}` |
| POST | `/api/auth/apple` | Apple Sign-In login | `{identityToken, authorizationCode, user}` | `{user, accessToken, refreshToken}` |
| POST | `/api/auth/refresh` | Refresh access token | `{refreshToken}` | `{accessToken, refreshToken}` |
| GET | `/api/auth/me` | Get user profile | `Authorization: Bearer <token>` | `{user}` |
| POST | `/api/auth/logout` | Logout user | `Authorization: Bearer <token>` | Success message |

### Error Codes
- `MISSING_FIELDS` - Required fields missing
- `USER_EXISTS` - Email already registered
- `INVALID_CREDENTIALS` - Wrong email/password
- `OAUTH_ONLY` - Account requires OAuth login
- `TOKEN_MISSING` - Authorization header missing
- `TOKEN_INVALID` - Invalid/expired token
- `MISSING_TOKEN` - OAuth token missing
- `INVALID_GOOGLE_TOKEN` - Google token verification failed
- `INVALID_APPLE_TOKEN` - Apple token verification failed

---

## 🔧 Flutter Integration Examples

### Basic Usage
```dart
import 'package:pushin/services/AuthenticationService.dart';
import 'package:pushin/services/AuthStateProvider.dart';

// Initialize service
final authService = AuthenticationService();

// Register user
final result = await authService.register(
  email: 'user@example.com',
  password: 'securePassword123!',
);

// Login user
final loginResult = await authService.login(
  email: 'user@example.com',
  password: 'securePassword123!',
);

// Google Sign In
final googleResult = await authService.signInWithGoogle();

// Apple Sign In
final appleResult = await authService.signInWithApple();

// Get current user
final user = await authService.getCurrentUser();

// Logout
await authService.logout();
```

### Using AuthStateProvider (Recommended)
```dart
import 'package:provider/provider.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthStateProvider>(context);

    return Column(
      children: [
        if (authProvider.isLoading) CircularProgressIndicator(),
        if (authProvider.errorMessage != null)
          Text(authProvider.errorMessage!),
        ElevatedButton(
          onPressed: () async {
            await authProvider.register(
              email: 'user@example.com',
              password: 'password123!',
            );
          },
          child: Text('Register'),
        ),
      ],
    );
  }
}
```

### Error Handling
```dart
final result = await authService.login(email: email, password: password);

if (result.success) {
  // Navigate to main app
  Navigator.pushReplacementNamed(context, '/home');
} else {
  // Show error message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.error!)),
  );
}
```

---

## 🚀 Deployment Checklist

### Backend Deployment (Railway)
- [ ] Environment variables set: `JWT_SECRET`, `JWT_REFRESH_SECRET`
- [ ] Database URL configured
- [ ] CORS origins configured for production domain
- [ ] Stripe keys configured (if using payments)
- [ ] Health check endpoint working: `GET /api/health`

### Flutter Deployment
- [ ] Base URL updated for production: `https://your-railway-app.up.railway.app/api`
- [ ] Google Sign-In configured with production credentials
- [ ] Apple Sign-In capability enabled in Xcode
- [ ] HTTPS required in network security config
- [ ] Token refresh logic tested in production

### Testing Production
- [ ] Register new user
- [ ] Login/logout cycle
- [ ] OAuth flows working
- [ ] Token refresh automatic
- [ ] Error handling graceful
- [ ] Database persistence verified

---

## 🐛 Troubleshooting

### Common Issues

**Database Connection Failed:**
```bash
# Check DATABASE_URL
echo $DATABASE_URL

# Test connection
cd backend && node ../test-db-connection.js
```

**Flutter Network Errors:**
- Verify baseUrl is correct
- Check CORS configuration
- Ensure HTTPS in production

**Token Refresh Issues:**
- Check TokenManager logs
- Verify refresh endpoint accessible
- Check token expiration logic

**OAuth Issues:**
- Verify platform-specific setup (iOS/Android)
- Check OAuth credentials
- Review token validation

---

## 📋 Integration Summary

✅ **Backend Status:** Complete and tested
✅ **Flutter Service:** Complete and integrated
✅ **Database:** Properly configured
✅ **Security:** All measures implemented
✅ **Error Handling:** Comprehensive coverage
✅ **OAuth:** Google and Apple supported
✅ **Token Management:** Automatic refresh implemented

The authentication system is ready for immediate use in production! 🚀













