# 🍽️ COMPLETE FOOD DATA INTEGRATION MAP
## Cal AI - OpenAI Vision API Integration Guide

Last Updated: January 14, 2026

---

## 📍 CRITICAL INTEGRATION POINTS

### 1. **PRIMARY DATA CAPTURE: Camera Scan View**
**Location**: Lines 14048-14165 (`CameraScanView`)

**Current Implementation:**
```swift
// Line 14101 - Camera shutter button
scannedFood = ScannedFood.sample

// Line 14158 - Photo library picker
scannedFood = ScannedFood.sample
```

**⚠️ ACTION REQUIRED:**
- Replace `ScannedFood.sample` with OpenAI Vision API call
- Send captured/selected UIImage to OpenAI
- Parse response into `ScannedFood` object
- Handle loading states and errors

**OpenAI Integration Point:**
```swift
// Pseudo-code for integration
Button(action: {
    // 1. Capture/select image
    let image = capturedUIImage
    
    // 2. Show loading state
    isAnalyzing = true
    
    // 3. Call OpenAI Vision API
    Task {
        let foodData = await analyzeFood(image: image)
        scannedFood = foodData
        currentStep = 5 // Move to detail view
    }
})
```

---

### 2. **DATA MODEL: ScannedFood Struct**
**Location**: Lines 14505-14540

**Current Model:**
```swift
struct ScannedFood {
    let name: String              // e.g., "Grilled Chicken Salad"
    let servings: Int            // e.g., 1
    let timestamp: String        // e.g., "3:08 PM"
    let calories: Int           // e.g., 350
    let protein: Int            // grams
    let carbs: Int              // grams
    let fats: Int               // grams
    let fiber: Int              // grams
    let sugar: Int              // grams
    let sodium: Int             // milligrams
    let healthScore: Int        // 0-10
    let icon: String            // emoji e.g., "🥗"
    let imageName: String?      // optional
    let ingredients: [String]   // detailed breakdown
}
```

**OpenAI Response Mapping:**
- Parse OpenAI response JSON to fill these fields
- Calculate health score based on nutritional balance
- Generate appropriate emoji icon based on food type
- Extract individual ingredients with their nutrition

---

### 3. **DATA DISPLAY: Food Detail View**
**Location**: Lines 14167-14404 (`FoodDetailView`)

**Displays (All from ScannedFood object):**
- Food icon/emoji (line 14237)
- Timestamp (line 14243)
- Food name + servings (lines 14253-14257)
- Main calories display (line 14279)
- Macros: Protein, Carbs, Fats (lines 14287-14289)
- Additional nutrients: Fiber, Sugar, Sodium (lines 14304-14306)
- Health score with progress bar (lines 14311-14338)
- Ingredients breakdown (lines 14370-14379)

**Features:**
- "Show more" toggle for detailed nutrients (line 14301)
- Edit serving size button (line 14261)
- Share functionality (line 14214)
- Done button to save (line 14388)

---

### 4. **DASHBOARD: Home View**
**Location**: Lines 12850-13084 (`HomeView`)

#### A. Weekly Calendar (Lines 12882-12919)
- Day selector with 7 days
- Currently selected day highlighted
- **ACTION REQUIRED**: Filter displayed food data by selected day

#### B. Main Calorie Card (Lines 12926-12971)
**Current Placeholder:**
- `"1388"` calories left (line 12934)

**Required Calculation:**
```
Calories Left = Daily Goal - Total Consumed Today
Daily Goal = From onboarding (lines 7017-7026)
  - Slow: 1800 cal
  - Medium: 1387 cal  
  - Fast: 1200 cal
Total Consumed = Sum of all scanned foods for selected day
```

**Additional Display:**
- Brain icon with "+1" (AI learning indicator)
- 🔥 emoji with circular progress

#### C. Macro Cards (Lines 12973-12998)
**Current Placeholders:**
- Protein: `"136g"` left (line 12976)
- Carbs: `"123g"` left (line 12984)
- Fat: `"38g"` left (line 12992)

**Required Calculation:**
```
Protein Left = Protein Goal - Total Protein Consumed
Carbs Left = Carbs Goal - Total Carbs Consumed
Fat Left = Fat Goal - Total Fat Consumed

Typical Macro Distribution (for 1387 cal):
- Protein: 30% = ~104g
- Carbs: 40% = ~138g
- Fat: 30% = ~46g
```

#### D. Recently Uploaded Section (Lines 13018-13071)
**Current State:** Empty placeholder
- Shows: "Tap + to add your first meal of the day"

**Required Display:**
- List of today's scanned foods
- Each item shows:
  - Food emoji/icon
  - Food name
  - Calories
  - Time
- Tap to view/edit details

---

### 5. **PROGRESS VIEW**
**Location**: Lines 13087-13780 (`ProgressView`)

#### A. Streak Counter (Lines 13099-13146)
- Current: `0` day streak
- **ACTION REQUIRED**: Increment streak when user logs food daily

#### B. Current Weight (Lines 13148-13206)
- Shows: "148 lbs"
- Goal display: "At your goal by Jul 16, 2026"
- **OPTIONAL**: Track weight correlation with calorie intake

#### C. Weight Progress Chart (Lines 13209-13273)
- Line graph showing weight over time
- Y-axis: 144-152 lbs
- **OPTIONAL**: Overlay daily calorie intake

#### D. BMI Card (Lines 13275-13419)
- Current BMI: 25.4 (Overweight)
- Color-coded scale
- **OPTIONAL**: Show how nutrition affects BMI

---

### 6. **PROFILE VIEW**
**Location**: Lines 13436-13667 (`ProfileView`)

**Current Features:**
- User info (name, email, avatar)
- Personal Details
- Language preferences
- Support email
- Terms & Privacy
- Logout/Delete account

**Potential Food Integration:**
- "Personal Details" → Could show nutrition goals
- Add "Nutrition Goals" section
- Add "Food History" section
- Add "Export Data" option

---

### 7. **ADD MENU OVERLAY**
**Location**: Lines 12744-12827

**Two Entry Points:**
1. **Food Database** (lines 12759-12786)
   - Manual search (OpenFoodFacts API - already implemented)
   - Lines 14638-14892

2. **Camera Scanner** (lines 12788-12817)
   - Opens `FoodScanFlow` → Triggers OpenAI Vision
   - Line 12666: `@State private var showScanFlow = false`

---

## 🔄 DATA FLOW ARCHITECTURE

```
1. USER TAKES PHOTO
   └─> CameraScanView (line 14097)
       └─> Capture UIImage

2. SEND TO OPENAI VISION API
   └─> analyzeFood(image: UIImage)
       └─> OpenAI GPT-4 Vision
           └─> Returns JSON with nutrition data

3. CREATE SCANNEDFOOOD OBJECT
   └─> Parse OpenAI response
       └─> Map to ScannedFood struct (line 14505)

4. DISPLAY IN FOODDETAILVIEW
   └─> Show all nutrition details (line 14167)
       └─> User can edit serving size
           └─> User taps "Done"

5. SAVE TO PERSISTENT STORAGE
   └─> Option A: UserDefaults (local only)
   └─> Option B: Firebase Firestore (recommended)
       └─> Collection: "users/{userId}/meals/{mealId}"

6. UPDATE DASHBOARD
   └─> HomeView (line 12850)
       └─> Recalculate daily totals
       └─> Update "Calories Left"
       └─> Update macro cards
       └─> Add to "Recently Uploaded"

7. UPDATE PROGRESS
   └─> ProgressView (line 13087)
       └─> Increment streak if daily goal met
       └─> Update weight correlation data
```

---

## 💾 DATA PERSISTENCE REQUIREMENTS

### Required Storage:
1. **Daily Food Logs**
   - Date
   - List of ScannedFood objects
   - Daily totals

2. **User Goals** (from onboarding)
   - Daily calorie target
   - Macro targets (protein, carbs, fat)
   - Weight goal
   - Timeline

3. **Streak Data**
   - Days logged
   - Last log date

### Recommended Structure (Firebase Firestore):
```
users/{userId}/
  ├─ profile/
  │   ├─ dailyCalorieGoal: 1387
  │   ├─ proteinGoal: 104
  │   ├─ carbsGoal: 138
  │   ├─ fatGoal: 46
  │   ├─ currentWeight: 148
  │   └─ targetWeight: 140
  │
  └─ meals/
      └─ {date}/
          ├─ {mealId1}/
          │   ├─ name: "Grilled Chicken Salad"
          │   ├─ timestamp: "2026-01-14T15:08:00Z"
          │   ├─ calories: 350
          │   ├─ protein: 35
          │   ├─ carbs: 25
          │   ├─ fats: 12
          │   ├─ fiber: 8
          │   ├─ sugar: 5
          │   ├─ sodium: 450
          │   ├─ healthScore: 8
          │   ├─ icon: "🥗"
          │   ├─ imageURL: "gs://..."
          │   └─ ingredients: [...]
          │
          └─ {mealId2}/
              └─ ...
```

---

## 🤖 OPENAI VISION API INTEGRATION

### Required API Call Structure:

```swift
func analyzeFood(image: UIImage) async throws -> ScannedFood {
    // 1. Convert UIImage to base64
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        throw FoodAnalysisError.imageConversionFailed
    }
    let base64Image = imageData.base64EncodedString()
    
    // 2. Prepare OpenAI request
    let prompt = """
    Analyze this food image and provide detailed nutritional information.
    Return a JSON object with the following fields:
    {
      "name": "Food name",
      "servings": 1,
      "calories": 0,
      "protein": 0,
      "carbs": 0,
      "fats": 0,
      "fiber": 0,
      "sugar": 0,
      "sodium": 0,
      "healthScore": 0-10,
      "icon": "emoji",
      "ingredients": ["item1", "item2"]
    }
    
    If multiple food items are visible, combine them into a single meal.
    Base nutritional values on typical serving sizes.
    Health score should consider nutritional balance, processing level, and ingredient quality.
    """
    
    let requestBody: [String: Any] = [
        "model": "gpt-4-vision-preview",
        "messages": [
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                ]
            ]
        ],
        "max_tokens": 1000
    ]
    
    // 3. Make API call
    // ... HTTP request to OpenAI ...
    
    // 4. Parse response
    // ... JSON parsing ...
    
    // 5. Return ScannedFood object
    return ScannedFood(...)
}
```

### API Endpoint:
```
POST https://api.openai.com/v1/chat/completions
Headers:
  Authorization: Bearer YOUR_OPENAI_API_KEY
  Content-Type: application/json
```

---

## 📊 CALCULATION FORMULAS

### Daily Totals:
```swift
func calculateDailyTotals(meals: [ScannedFood]) -> DailyTotals {
    let totalCalories = meals.reduce(0) { $0 + $1.calories }
    let totalProtein = meals.reduce(0) { $0 + $1.protein }
    let totalCarbs = meals.reduce(0) { $0 + $1.carbs }
    let totalFats = meals.reduce(0) { $0 + $1.fats }
    
    return DailyTotals(
        calories: totalCalories,
        protein: totalProtein,
        carbs: totalCarbs,
        fats: totalFats
    )
}
```

### Remaining Values:
```swift
func calculateRemaining(consumed: DailyTotals, goals: NutritionGoals) -> DailyTotals {
    return DailyTotals(
        calories: max(0, goals.calories - consumed.calories),
        protein: max(0, goals.protein - consumed.protein),
        carbs: max(0, goals.carbs - consumed.carbs),
        fats: max(0, goals.fats - consumed.fats)
    )
}
```

### Streak Calculation:
```swift
func calculateStreak(logDates: [Date]) -> Int {
    let sortedDates = logDates.sorted(by: >)
    var streak = 0
    var currentDate = Calendar.current.startOfDay(for: Date())
    
    for date in sortedDates {
        let logDate = Calendar.current.startOfDay(for: date)
        
        if logDate == currentDate {
            streak += 1
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
        } else {
            break
        }
    }
    
    return streak
}
```

---

## ✅ IMPLEMENTATION CHECKLIST

### Phase 1: OpenAI Integration
- [ ] Add OpenAI API key to app configuration
- [ ] Create `FoodAnalysisService` class
- [ ] Implement `analyzeFood(image:)` function
- [ ] Add error handling and retry logic
- [ ] Test with various food images
- [ ] Add loading states to UI

### Phase 2: Data Persistence
- [ ] Create Firestore data models
- [ ] Implement save meal function
- [ ] Implement fetch meals for date
- [ ] Add offline support with local cache
- [ ] Sync with Firebase when online

### Phase 3: Dashboard Integration
- [ ] Calculate daily totals from saved meals
- [ ] Update calories remaining display
- [ ] Update macro cards
- [ ] Populate "Recently Uploaded" section
- [ ] Add pull-to-refresh

### Phase 4: Progress Tracking
- [ ] Implement streak calculation
- [ ] Update streak counter
- [ ] Add streak animations
- [ ] Add goal achievement notifications

### Phase 5: Polish & Features
- [ ] Add meal editing functionality
- [ ] Add meal deletion
- [ ] Add meal history view
- [ ] Export nutrition data
- [ ] Add nutrition insights/tips
- [ ] Add weekly/monthly summaries

---

## 🎯 PLACEHOLDER DATA TO REPLACE

### Lines to Update:
1. **Line 12934**: `"1388"` → Calculate actual calories remaining
2. **Line 12976**: `"136g"` → Calculate actual protein remaining
3. **Line 12984**: `"123g"` → Calculate actual carbs remaining
4. **Line 12992**: `"38g"` → Calculate actual fat remaining
5. **Line 13061**: Empty meal placeholder → Show actual meals
6. **Line 12868**: `0` streak → Calculate actual streak
7. **Line 14101**: `ScannedFood.sample` → OpenAI result
8. **Line 14158**: `ScannedFood.sample` → OpenAI result

---

## 🚨 IMPORTANT NOTES

1. **User Goals from Onboarding**:
   - Lines 7017-7026 show calorie calculation
   - Based on weight loss speed selected
   - Must be saved to user profile

2. **Existing OpenAI Cache**:
   - Lines 458-760 show caching system
   - Already implemented for other features
   - Can reuse for food analysis caching

3. **Firebase Already Integrated**:
   - Lines 16-21 show Firebase imports
   - AuthenticationManager already exists
   - Can extend for meal storage

4. **Image Handling**:
   - UIImage picker already implemented
   - Lines 14464-14503 show ImagePicker
   - Can capture from camera or photo library

---

## 📞 NEXT STEPS

**AWAITING YOUR OPENAI API KEYS TO:**
1. Integrate OpenAI Vision API
2. Replace placeholder data with real calculations
3. Implement data persistence
4. Connect all UI components to live data

**Ready to proceed once you provide:**
- OpenAI API Key
- Any specific preferences for:
  - Storage method (Firebase vs local)
  - Calculation methods
  - UI behavior

---

*This document maps every location in your 15,780-line ContentView.swift file where food data is relevant.*
