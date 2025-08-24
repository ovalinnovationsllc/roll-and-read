# 🚀 Google Gemini API Setup Guide

Your Roll and Read app is now configured to use Google Gemini AI for generating educational word grids!

## ✅ **Current Status**
- **Demo Mode**: Currently enabled (works without API key)
- **Real AI**: Ready to enable with your Gemini API key
- **Free Tier**: 15 requests/minute when enabled

## 🔑 **How to Enable Real AI (FREE)**

### Step 1: Get Your Gemini API Key
1. Go to **Google AI Studio**: https://makersuite.google.com/app/apikey
2. **Sign in** with your Google account
3. Click **"Create API Key"**
4. **Copy** the generated key (starts with `AIza...`)

### Step 2: Add API Key to Your App
1. Open `lib/services/ai_word_service.dart`
2. Find line 10: `static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';`
3. Replace `YOUR_GEMINI_API_KEY_HERE` with your actual API key
4. **Optional**: Change `_useDemoMode = false` on line 13 to use real AI

### Step 3: Test the AI
1. **Restart your app**
2. **Create a new game** as admin
3. **Toggle on "Use AI Generated Words"**
4. **Enter prompts** like:
   - "farm animals"
   - "space adventure"
   - "healthy foods"
   - "ocean creatures"
   - "winter activities"

## 🆓 **Free Tier Limits**
- **15 requests per minute** (plenty for classroom use!)
- **No daily limit**
- **No credit card required**
- **Perfect for educational apps**

## 🎯 **AI Features You Get**

### **Smart Content Generation**
- Words appropriate for grade level
- Educational and safe content
- Themed word grids based on teacher prompts
- Automatic difficulty adjustment

### **Built-in Safety**
- Content filtering for children
- Educational focus
- No inappropriate words
- Compliant with school standards

## 🔄 **Demo vs Real AI**

| Feature | Demo Mode | Real Gemini AI |
|---------|-----------|----------------|
| **Cost** | Free | Free (15/min) |
| **Topics** | 7 preset themes | Unlimited custom |
| **Quality** | Good | Excellent |
| **Customization** | Limited | Full teacher control |
| **Setup** | None required | 5-minute setup |

## 🛠 **Troubleshooting**

### **API Key Issues**
- Make sure key starts with `AIza`
- No spaces before/after the key
- Key must be in quotes: `"AIzaYourKeyHere"`

### **Rate Limits**
- Free tier: 15 requests/minute
- If you hit limits, wait 60 seconds
- Or keep demo mode as fallback

### **Error Messages**
- `403 Forbidden`: Check your API key
- `429 Too Many Requests`: Wait a minute
- `Network error`: Check internet connection

## 💡 **Pro Tips**

1. **Keep Demo Mode**: Leave `_useDemoMode = true` as fallback
2. **Test Prompts**: Start with simple topics like "animals" or "colors"  
3. **Grade Levels**: Use "kindergarten", "elementary", "middle-school"
4. **Specific Requests**: Try "words that rhyme with cat" or "long vowel sounds"

## 🎓 **Example Prompts That Work Great**

### **By Subject**
- Science: "solar system planets", "parts of a plant"
- Math: "shapes and numbers", "counting to ten"
- Reading: "long A sounds", "words with -ing ending"
- Social Studies: "community helpers", "maps and directions"

### **By Theme**
- Seasonal: "summer activities", "winter sports"
- Animals: "zoo animals", "farm creatures", "ocean life"
- Food: "healthy snacks", "fruits and vegetables"
- Sports: "playground games", "team sports"

---

**Ready to try it?** Get your free API key and unlock unlimited educational content generation! 🎉