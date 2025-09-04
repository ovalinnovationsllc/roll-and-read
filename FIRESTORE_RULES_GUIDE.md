# Firestore Security Rules Guide

## Overview
This document explains the production-ready Firestore security rules for the Roll and Read application using a **hybrid authentication system**.

## Hybrid Authentication Architecture

### Authentication Methods:
1. **Teachers**: Use Firebase Auth (email/password) for secure admin operations
2. **Students**: Use simple game codes (no authentication) to join games

### Security Benefits:
- ✅ **Admin Security**: Teachers have proper authentication and authorization
- ✅ **Student Simplicity**: Students just enter game codes (no accounts needed)
- ✅ **Database Protection**: Only authenticated teachers can modify/delete data
- ✅ **Audit Trail**: All teacher actions are logged with Firebase user IDs

## Database Structure

### Active Collections:
1. **users** - Contains both teachers (isAdmin: true) and students (isAdmin: false)
2. **games** - Game configurations created by teachers
3. **gameStates** - Active game states and progress
4. **wordLists** - Word lists for games (can be public or private)

## User Types

### Teachers (Firebase Auth + isAdmin: true)
- Must authenticate with Firebase Auth (email/password)
- Can create and manage students, games, word lists
- Can run cleanup operations and admin functions
- All actions are logged with their Firebase UID

### Students (Game Codes + isAdmin: false)
- No authentication required - just enter game codes
- Can join games and participate in gameplay
- Cannot modify admin data or perform destructive operations
- Created and managed by teachers

## Security Rules Breakdown

### Teacher Operations (Require Firebase Auth):
- ✅ Create/modify/delete games
- ✅ Create/modify/delete word lists  
- ✅ Create/modify/delete users (students)
- ✅ Run cleanup operations
- ✅ Access admin dashboard

### Student Operations (No Auth Required):
- ✅ Read games (to join with codes)
- ✅ Read/write game states (during gameplay)
- ✅ Read word lists (during games)
- ❌ Cannot modify admin data
- ❌ Cannot delete or create permanent records

### Database-Level Security:
- **Collection Access**: Only specific collections accessible
- **Operation Control**: Write operations restricted to authenticated teachers
- **Read Access**: Students can read game-related data for participation
- **Unknown Collections**: Blocked completely

## Deployment Steps for Production

### 1. Create Teacher Firebase Auth Accounts
For each teacher, create a Firebase Auth account:
```bash
# In Firebase Console > Authentication > Users
# Add users manually or use Firebase Admin SDK
```

### 2. Link Firebase UID to User Records
Each teacher's Firestore user document must have:
- Document ID = Firebase Auth UID
- `isAdmin: true` field
- Other profile data

### 3. Test Rules Locally
```bash
firebase emulators:start --only firestore,auth
```

### 4. Deploy Rules
```bash
firebase deploy --only firestore:rules
```

### 5. Migration from Old System
If migrating from email-only system:
1. Create Firebase Auth accounts for existing teachers
2. Update user document IDs to match Firebase UIDs
3. Test login and admin operations
4. Deploy new rules

## Security Model Details

### Authentication Flow:
1. **Teacher Login**: 
   - Firebase Auth validates email/password
   - App gets Firebase user with UID
   - App loads Firestore user profile using UID
   - Admin operations use Firebase Auth token

2. **Student Game Join**:
   - Student enters game code
   - App queries games collection (no auth needed)
   - Student joins game and can participate
   - Game state updates work without authentication

### Permission Matrix:
| Operation | Teachers (Auth) | Students (No Auth) |
|-----------|----------------|-------------------|
| Read users | ✅ | ✅ |
| Write users | ✅ | ❌ |
| Read games | ✅ | ✅ |
| Write games | ✅ | ❌ |
| Read gameStates | ✅ | ✅ |
| Write gameStates | ✅ | ✅ |
| Read wordLists | ✅ | ✅ |
| Write wordLists | ✅ | ❌ |
| Cleanup operations | ✅ | ❌ |

## Security Best Practices

### 1. Firebase Auth Configuration
- Enable email/password authentication
- Set strong password requirements
- Configure session timeouts appropriately
- Monitor authentication logs

### 2. Teacher Account Management
- Use strong passwords for teacher accounts
- Regular password updates
- Monitor for unusual login patterns
- Disable unused accounts promptly

### 3. Application Security
- Validate game codes before database queries
- Implement rate limiting for game joins
- Monitor for abuse patterns
- Proper error handling without information leakage

## Monitoring and Maintenance

### 1. Authentication Monitoring
- Track teacher login patterns
- Monitor failed authentication attempts
- Alert on unusual access patterns
- Regular security audits

### 2. Database Operations
- Cleanup operations now require teacher authentication
- All admin operations are logged with user IDs
- Monitor for unauthorized access attempts
- Track game participation patterns

### 3. Performance Monitoring
- Database operation timing is logged
- Cleanup operations show detailed progress
- Failed operations are logged with details
- Authentication performance tracking

## Troubleshooting

### Common Issues:

**Teacher Login Problems:**
- Check Firebase Auth configuration
- Verify user document ID matches Firebase UID
- Confirm `isAdmin: true` field is set
- Check network connectivity

**Student Game Join Problems:**
- Verify game codes are correct
- Check games collection read permissions
- Ensure game states are accessible
- Validate game status

**Cleanup Operations Failing:**
- Confirm teacher is authenticated with Firebase Auth
- Check user has `isAdmin: true`
- Verify Firestore rules allow teacher operations
- Check Firebase Auth token validity

## Future Enhancements

Potential improvements:
- Custom claims for more granular permissions
- Role-based access beyond admin/student
- Server-side API for sensitive operations
- Enhanced logging and monitoring
- Multi-tenant support for multiple schools