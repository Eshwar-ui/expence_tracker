# Quick Fix: Recreate Mobile-Compatible Model

## The Problem
Your current `expense_predictor.tflite` model uses TensorFlow ops that aren't supported by the mobile TFLite runtime. You need to recreate it with compatibility settings.

## Solution: Google Colab (Fastest)

### Step 1: Open Colab
Go to: https://colab.research.google.com/

### Step 2: Create New Notebook
File → New notebook

### Step 3: Copy & Paste This Code

```python
# Install dependencies
!pip install -q tensorflow>=2.16.0 numpy>=1.24.3 pandas>=2.0.3

# Import libraries
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from datetime import datetime, timedelta
import os

print(f"TensorFlow version: {tf.__version__}")

# ============================================================================
# DATA GENERATION (Same as your training script)
# ============================================================================

def generate_synthetic_data(num_users=200, days_per_user=180):
    np.random.seed(42)
    expenses = []
    categories = [
        'Food & Dining', 'Transportation', 'Shopping', 'Entertainment',
        'Bills & Utilities', 'Healthcare', 'Education', 'Travel',
        'Personal Care', 'Subscriptions', 'Insurance', 'Other'
    ]
    base_date = datetime.now() - timedelta(days=days_per_user)
    
    for user_id in range(num_users):
        base_daily_spend = np.random.uniform(200, 1000)
        category_weights = np.random.dirichlet(np.ones(len(categories)))
        
        for day_offset in range(days_per_user):
            date = base_date + timedelta(days=day_offset)
            day_factor = 1.2 if date.weekday() >= 5 else 1.0
            month_end_factor = 1.3 if date.day >= 28 else 1.0
            daily_total = base_daily_spend * day_factor * month_end_factor * np.random.uniform(0.5, 1.5)
            num_transactions = np.random.poisson(3)
            
            remaining = daily_total
            for i, category in enumerate(categories[:-1]):
                if remaining <= 0:
                    break
                if np.random.random() < category_weights[i]:
                    amount = min(remaining, np.random.uniform(50, daily_total * category_weights[i] * 2))
                    remaining -= amount
                    expenses.append({
                        'amount': amount,
                        'date': date.isoformat(),
                        'category': category,
                        'type': 'expense',
                    })
            
            if remaining > 0:
                expenses.append({
                    'amount': remaining,
                    'date': date.isoformat(),
                    'category': 'Other',
                    'type': 'expense',
                })
    
    return expenses

# ============================================================================
# DATA PREPROCESSING
# ============================================================================

class ExpenseDataPreprocessor:
    def __init__(self, sequence_length=30, prediction_horizon=30):
        self.sequence_length = sequence_length
        self.prediction_horizon = prediction_horizon
        self.feature_stats = {}
    
    def prepare_features(self, expenses):
        df = pd.DataFrame(expenses)
        df['date'] = pd.to_datetime(df['date'])
        df = df.sort_values('date')
        df = df[df['type'] == 'expense'].copy()
        
        daily_data = []
        start_date = df['date'].min()
        end_date = df['date'].max()
        date_range = pd.date_range(start=start_date, end=end_date, freq='D')
        
        for date in date_range:
            day_expenses = df[df['date'].dt.date == date.date()]
            daily_total = day_expenses['amount'].sum() if len(day_expenses) > 0 else 0.0
            category_totals = day_expenses.groupby('category')['amount'].sum().to_dict()
            num_transactions = len(day_expenses)
            day_of_week = date.weekday()
            day_of_month = date.day
            is_weekend = 1 if day_of_week >= 5 else 0
            is_month_end = 1 if date.day >= 28 else 0
            is_month_start = 1 if date.day <= 5 else 0
            
            daily_data.append({
                'date': date,
                'daily_total': daily_total,
                'num_transactions': num_transactions,
                'day_of_week': day_of_week,
                'day_of_month': day_of_month,
                'is_weekend': is_weekend,
                'is_month_end': is_month_end,
                'is_month_start': is_month_start,
                'category_totals': category_totals,
            })
        
        daily_df = pd.DataFrame(daily_data)
        
        # Get top categories
        all_categories = set()
        for cats in daily_df['category_totals']:
            all_categories.update(cats.keys())
        category_totals_all = {}
        for cats in daily_df['category_totals']:
            for cat, amount in cats.items():
                category_totals_all[cat] = category_totals_all.get(cat, 0) + amount
        top_categories = sorted(category_totals_all.items(), key=lambda x: x[1], reverse=True)[:10]
        top_categories = [cat for cat, _ in top_categories]
        
        # Create sequences
        sequences = []
        targets = []
        for i in range(len(daily_df) - self.sequence_length - self.prediction_horizon + 1):
            seq_data = daily_df.iloc[i:i + self.sequence_length]
            target_data = daily_df.iloc[i + self.sequence_length:i + self.sequence_length + self.prediction_horizon]
            
            features = []
            for _, row in seq_data.iterrows():
                feature_vector = [
                    row['daily_total'],
                    row['num_transactions'],
                    row['day_of_week'] / 6.0,
                    row['day_of_month'] / 31.0,
                    row['is_weekend'],
                    row['is_month_end'],
                    row['is_month_start'],
                ]
                for cat in top_categories:
                    feature_vector.append(row['category_totals'].get(cat, 0.0))
                features.append(feature_vector)
            
            sequences.append(features)
            targets.append(target_data['daily_total'].values.tolist())
        
        X = np.array(sequences, dtype=np.float32)
        y = np.array(targets, dtype=np.float32)
        
        self.feature_stats = {
            'mean': float(np.mean(X)),
            'std': float(np.std(X)),
            'categories': top_categories,
        }
        
        X = (X - self.feature_stats['mean']) / (self.feature_stats['std'] + 1e-8)
        y = np.log1p(y)
        
        return X, y

# ============================================================================
# MODEL ARCHITECTURE
# ============================================================================

def create_model(sequence_length=30, num_features=17, prediction_horizon=30):
    inputs = keras.Input(shape=(sequence_length, num_features), name='expense_sequence')
    
    x = layers.LSTM(64, return_sequences=True, dropout=0.2, recurrent_dropout=0.2)(inputs)
    x = layers.LSTM(32, return_sequences=False, dropout=0.2, recurrent_dropout=0.2)(x)
    
    x = layers.Dense(128, activation='relu')(x)
    x = layers.Dropout(0.3)(x)
    x = layers.BatchNormalization()(x)
    
    x = layers.Dense(64, activation='relu')(x)
    x = layers.Dropout(0.3)(x)
    x = layers.BatchNormalization()(x)
    
    x = layers.Dense(32, activation='relu')(x)
    x = layers.Dropout(0.3)(x)
    
    outputs = layers.Dense(prediction_horizon, activation='relu', name='daily_predictions')(x)
    
    model = keras.Model(inputs=inputs, outputs=outputs, name='expense_predictor')
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='mse',
        metrics=['mae', 'mape']
    )
    
    return model

# ============================================================================
# TRAIN MODEL
# ============================================================================

print("Generating data...")
synthetic_data = generate_synthetic_data(num_users=200, days_per_user=180)
print(f"Generated {len(synthetic_data)} expenses")

print("Preprocessing...")
preprocessor = ExpenseDataPreprocessor(sequence_length=30, prediction_horizon=30)
X, y = preprocessor.prepare_features(synthetic_data)
print(f"X shape: {X.shape}, y shape: {y.shape}")

# Split data
split_idx = int(len(X) * 0.8)
X_train, X_val = X[:split_idx], X[split_idx:]
y_train, y_val = y[:split_idx], y[split_idx:]

print("Creating model...")
model = create_model(sequence_length=30, num_features=X.shape[2], prediction_horizon=30)
model.summary()

print("Training...")
history = model.fit(
    X_train, y_train,
    batch_size=32,
    epochs=30,
    validation_data=(X_val, y_val),
    verbose=1
)

# ============================================================================
# CONVERT TO MOBILE-COMPATIBLE TFLITE
# ============================================================================

print("\n" + "="*60)
print("Converting to TFLite (MOBILE COMPATIBLE)")
print("="*60)

# CRITICAL: Use mobile-compatible settings
converter = tf.lite.TFLiteConverter.from_keras_model(model)

# Use only built-in ops (no experimental features)
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]

# Disable experimental features
converter.experimental_new_converter = True
converter.experimental_new_quantizer = False

# Convert (float32, no quantization for compatibility)
tflite_model = converter.convert()

# Save
os.makedirs('models', exist_ok=True)
with open('models/expense_predictor.tflite', 'wb') as f:
    f.write(tflite_model)

print(f"✅ TFLite model saved: {len(tflite_model) / (1024*1024):.2f} MB")

# Save stats
import json
stats = {
    'sequence_length': 30,
    'prediction_horizon': 30,
    'num_features': X.shape[2],
    'feature_stats': preprocessor.feature_stats
}
with open('models/expense_predictor_stats.json', 'w') as f:
    json.dump(stats, f, indent=2)

print("✅ Stats saved")

# Test the model
interpreter = tf.lite.Interpreter(model_path='models/expense_predictor.tflite')
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"\n✅ Model verified:")
print(f"   Input shape: {input_details[0]['shape']}")
print(f"   Output shape: {output_details[0]['shape']}")

# Download files
from google.colab import files
print("\n📥 Downloading files...")
files.download('models/expense_predictor.tflite')
files.download('models/expense_predictor_stats.json')

print("\n✅ Done! Replace the files in your Flutter project:")
print("   1. Copy expense_predictor.tflite to assets/models/")
print("   2. Copy expense_predictor_stats.json to assets/models/")
print("   3. Hot restart your Flutter app")
```

### Step 4: Run All Cells
Runtime → Run all (or press Shift+Enter for each cell)

### Step 5: Download Files
The notebook will automatically download:
- `expense_predictor.tflite`
- `expense_predictor_stats.json`

### Step 6: Replace in Flutter Project
1. Copy `expense_predictor.tflite` to `assets/models/`
2. Copy `expense_predictor_stats.json` to `assets/models/`
3. Hot restart the app (not just hot reload)

## Key Differences in This Model

✅ Uses `TFLITE_BUILTINS` only (no experimental ops)
✅ Float32 precision (no quantization)
✅ Disabled experimental converters
✅ Compatible with mobile TFLite runtime

## Verification

After replacing the model, you should see:
```
✅ AI Model loaded successfully
   Input shape: [1, 30, 17]
   Output shape: [1, 30]
```

Instead of the compatibility error.
