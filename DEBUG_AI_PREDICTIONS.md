# Debugging AI Predictions

## Enhanced Logging Added

I've added comprehensive logging throughout the AI prediction pipeline. When you run the app and try to load predictions, check the console for these messages:

### 1. Model Loading
```
📦 Loading TFLite model from assets/models/expense_predictor.tflite...
📦 Model file loaded: [size] bytes
✅ AI Model loaded successfully
   Input shape: [1, 30, 17]
   Output shape: [1, 30]
```

### 2. Data Fetching
```
📊 Fetching expense data...
📊 Found [X] total expenses
📊 Found [X] expenses in last 30 days
📊 Using [X] expense records for prediction
```

### 3. Feature Preparation
```
📅 Date range: [start] to [end]
📅 Days difference: [X] (need at least 30)
📊 Preparing features for 30 days
✅ Prepared 30 feature vectors, each with 17 features
📊 Normalizing features: mean=[X], std=[Y]
✅ Features normalized and ready for inference
```

### 4. Inference
```
🔮 Running inference...
   Input shape: [1, 30, 17]
   Output shape: [1, 30]
✅ Inference completed
   Predictions: 30 values
   Sample (first 5): [...]
```

## Common Issues & Solutions

### Issue 1: "Model file not found"
**Solution:**
1. Verify file exists: `assets/models/expense_predictor.tflite`
2. Check `pubspec.yaml` includes `assets/models/`
3. Run `flutter clean && flutter pub get`
4. Rebuild app (not just hot reload)

### Issue 2: "Not enough days of data"
**Problem:** Expenses exist but not spread over 30 days
**Solution:** 
- Add more expenses over time
- Or modify `_sequenceLength` requirement (not recommended)

### Issue 3: "Model initialization failed"
**Check console for:**
- Compatibility errors (FULLY_CONNECTED version 12)
- File loading errors
- Tensor shape mismatches

### Issue 4: "Prediction returned null"
**Possible causes:**
- Not enough expense data
- All expenses are income (not expense type)
- Date range too small
- Feature preparation failed

## Testing Steps

1. **Check Model File:**
   ```bash
   ls -lh assets/models/expense_predictor.tflite
   ```

2. **Check Stats File:**
   ```bash
   cat assets/models/expense_predictor_stats.json
   ```

3. **Run App with Logs:**
   ```bash
   flutter run
   ```

4. **Navigate to AI Predictions Screen**

5. **Watch Console Output:**
   - Look for error messages
   - Check which step fails
   - Note the exact error text

## Quick Fixes

### If model doesn't load:
- Recreate model with mobile-compatible settings (see FIX_TFLITE_COMPATIBILITY.md)
- Replace model file
- Hot restart app

### If not enough data:
- Add at least 30 days of expense history
- Ensure expenses are spread over time (not all on one day)
- Verify expenses have `type == 'expense'`

### If inference fails:
- Check input/output tensor shapes match expected values
- Verify feature normalization is correct
- Check model file isn't corrupted

## Next Steps

After running the app, share the console output so we can identify the exact failure point.
