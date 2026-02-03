# Expense Prediction ML Model

Machine learning model for predicting future expenses based on historical spending patterns.

## Setup

1. **Create virtual environment** (recommended):
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. **Install dependencies**:
```bash
pip install -r requirements.txt
```

## Training the Model

### Step 1: Generate Training Data
The model uses synthetic data generation for training. You can modify `data_preprocessor.py` to use real user data.

### Step 2: Train the Model
```bash
python train_model.py
```

This will:
- Generate synthetic expense data
- Preprocess and create sequences
- Train the LSTM model
- Save model to `models/expense_predictor.h5`
- Save preprocessing stats to `models/expense_predictor_stats.json`

### Step 3: Convert to TensorFlow Lite
```bash
python convert_to_tflite.py
```

This will:
- Load the trained model
- Convert to TFLite format
- Apply INT8 quantization (for mobile optimization)
- Save to `models/expense_predictor.tflite`
- Create metadata file

## Model Architecture

- **Input**: Sequence of 30 days with 17 features per day
- **Architecture**: 
  - LSTM layers (64, 32 units) for temporal patterns
  - Dense layers (128, 64, 32 units) for predictions
  - Dropout and BatchNormalization for regularization
- **Output**: Predictions for next 30 days of daily spending
- **Optimization**: INT8 quantization for mobile deployment
- **Size**: ~1-2 MB (quantized)

## Features Used

1. Daily total spending
2. Number of transactions per day
3. Day of week (normalized)
4. Day of month (normalized)
5. Is weekend (binary)
6. Is month end (binary)
7. Is month start (binary)
8. Top 10 category spending amounts

## Usage in Flutter

1. Copy `models/expense_predictor.tflite` to `assets/models/` in Flutter project
2. Copy `models/expense_predictor_stats.json` to `assets/models/`
3. Use `tflite_flutter` package to load and run inference
4. See `lib/services/ai_expense_service.dart` for integration

## Model Performance

- **Training**: ~50 epochs with early stopping
- **Validation Loss**: Typically < 0.1 (on log scale)
- **MAE**: Mean Absolute Error on validation set
- **Inference Time**: < 50ms on mobile devices

## Customization

### Using Real User Data

Modify `train_model.py` to load real expense data:

```python
# Load from Firestore or JSON
real_expenses = load_user_expenses(user_id)
X, y = preprocessor.prepare_features(real_expenses)
```

### Adjusting Model Parameters

Edit `model_architecture.py`:
- `lstm_units`: Number of LSTM units (default: 64)
- `dense_units`: List of dense layer sizes
- `sequence_length`: Input sequence length (default: 30 days)
- `prediction_horizon`: Days to predict (default: 30)

### Fine-tuning for Specific Users

1. Train base model on synthetic data
2. Load user's historical data
3. Fine-tune model with user-specific data
4. Convert to TFLite

## Troubleshooting

### Out of Memory
- Reduce `batch_size` in training
- Reduce `num_users` in synthetic data generation
- Use smaller LSTM units

### Poor Predictions
- Increase training data (more users/days)
- Adjust model architecture
- Check feature normalization
- Verify data preprocessing

### TFLite Conversion Issues
- Ensure TensorFlow version >= 2.15.0
- Check model input/output shapes
- Verify quantization calibration data

