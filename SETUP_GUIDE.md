# Roll and Read Setup Guide

## Initial Setup Steps

### 1. Create Admin User in Firestore

1. Go to your Firebase Console
2. Navigate to Firestore Database
3. Create a new collection called `users`
4. Add a document with the following structure:

```json
{
  "id": "admin1",
  "displayName": "Mrs. Elson",
  "emailAddress": "admin@school.com",
  "pin": "1234",
  "isAdmin": true,
  "gamesPlayed": 0,
  "gamesWon": 0,
  "wordsCorrect": 0,
  "createdAt": [current timestamp]
}
```

### 2. Deploy Firestore Rules

Deploy the permissive rules for testing:

```bash
firebase deploy --only firestore:rules
```

Or manually update in Firebase Console:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

### 3. Test Admin Login

1. Visit http://localhost:8081
2. Click "Admin" at the bottom
3. Enter: `admin@school.com`
4. You should now access the admin dashboard

### 4. Create a Game with AI Words

1. In Admin Dashboard, click "Create Game" (box icon)
2. Enter game name: "Reading Practice 1"
3. Toggle ON "Use AI Generated Words"
4. Select reading level
5. Enter prompt or select template:
   - "Animals that live in the ocean"
   - "Words with long vowel sounds"
   - "Food we eat for breakfast"
6. Click "Create Game"
7. Note the 6-character Game ID (e.g., ABC123)

### 5. Create Student Users

1. Click "Create User" (person icon)
2. Enter student details
3. Generate or enter 4-digit PIN
4. Save the credentials for students

### 6. Test Student Game Join

1. Open new browser tab/window
2. Visit http://localhost:8081
3. Click "Join Game"
4. Enter:
   - Game ID: [from step 4]
   - Email: [student email]
   - PIN: [student PIN]
5. Student joins the waiting room

### 7. Start the Game

1. Return to Admin Dashboard
2. Find the game in "Active Games" section
3. Click on the game
4. Click "Start Game" when players are ready

## Troubleshooting

### "Error creating game"
- Check Firestore rules are permissive
- Check browser console for errors
- Ensure admin user exists in Firestore
- Verify Firebase configuration is correct

### "User not found"
- Create admin user in Firestore first
- Ensure email matches exactly
- Check isAdmin field is set to true

### "Game not found"
- Game IDs are case-sensitive
- Use the exact 6-character code
- Check game hasn't been deleted

### AI Words Not Generating
- Demo AI service is enabled by default
- No API keys required for testing
- Falls back to default words if issues

## Production Setup

Before going to production:

1. **Update Firestore Rules** - Implement proper security rules
2. **Add Real AI API Keys** - Replace demo AI with OpenAI/Claude
3. **Environment Variables** - Store sensitive keys securely
4. **User Authentication** - Consider Firebase Auth for production
5. **Error Logging** - Add proper error tracking
6. **Analytics** - Track game usage and learning outcomes