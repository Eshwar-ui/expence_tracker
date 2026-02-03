# AI Expense Prediction Model - Setup Guide

## Overview

This directory contains the Python scripts to train a machine learning model that predicts future expenses based on historical spending patterns. The trained model is converted to TensorFlow Lite format for integration into the Flutter app.

## Prerequisites

1. **Python 3.8+** installed on your system
2. **pip** package manager
3. **TensorFlow 2.15.0+** (will be installed via requirements.txt)

## Quick Start

### Step 1: Set Up Python Environment

```bash
# Navigate to ml_model directory
cd ml_model

# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Step 2: Train the Model

```bash
python train_model.py
```

This will:
- Generate synthetic training data (200 users, 180 days each)
- Preprocess the data into sequences
- Train an LSTM-based neural network
- Save the model to `models/expense_predictor.h5`
- Save metadata to `models/expense_predictor_stats.json`

**Expected time**: 5-15 minutes depending on your hardware

### Step 3: Convert to TensorFlow Lite

```bash
python convert_to_tflite.py
```

This will:
- Load the trained Keras model
- Convert to TensorFlow Lite format
- Apply INT8 quantization for mobile optimization
- Save to `models/expense_predictor.tflite`

**Model size**: ~1-2 MB (quantized)

### Step 4: Copy to Flutter Assets

```bash
# From project root
# Copy TFLite model
copy ml_model\models\expense_predictor.tflite assets\models\  # Windows
cp ml_model/models/expense_predictor.tflite assets/models/     # macOS/Linux

# Copy metadata
copy ml_model\models\expense_predictor_stats.json assets\models\  # Windows
cp ml_model/models/expense_predictor_stats.json assets/models/    # macOS/Linux
```

### Step 5: Test in Flutter App

1. Run `flutter pub get` to install `tflite_flutter` dependency
2. Navigate to AI Predictions screen in the app
3. The model will automatically load and make predictions

## Model Architecture

- **Input**: 30 days of expense history (17 features per day)
- **Architecture**: 
  - 2 LSTM layers (64, 32 units)
  - 3 Dense layers (128, 64, 32 units)
  - Dropout and BatchNormalization
- **Output**: 30 days of predicted daily spending
- **Optimization**: INT8 quantization

## Features Used

1. Daily total spending
2. Number of transactions
3. Day of week (normalized)
4. Day of month (normalized)
5. Is weekend (binary)
6. Is month end (binary)
7. Is month start (binary)
8. Top 10 category spending amounts

## Customization

### Using Real User Data

To train on actual user data instead of synthetic data:

1. Export expenses from Firestore to JSON format
2. Modify `train_model.py`:

```python
# Replace synthetic data generation with:
import json
with open('user_expenses.json', 'r') as f:
    real_expenses = json.load(f)
X, y = preprocessor.prepare_features(real_expenses)
```

### Adjusting Model Parameters

Edit `model_architecture.py`:
- `lstm_units`: Number of LSTM units (default: 64)
- `dense_units`: Dense layer sizes (default: [128, 64, 32])
- `sequence_length`: Input days (default: 30)
- `prediction_horizon`: Prediction days (default: 30)

### Fine-tuning for Specific Users

1. Train base model on synthetic data
2. Load user's historical expenses
3. Fine-tune with user-specific data
4. Convert to TFLite

## Troubleshooting

### Python Not Found
- Ensure Python is installed and in PATH
- Use `python3` instead of `python` on some systems

### TensorFlow Installation Issues
- Use `pip install tensorflow==2.15.0` directly
- For Apple Silicon Macs, use `tensorflow-macos`

### Out of Memory During Training
- Reduce `batch_size` in `train_model.py`
- Reduce `num_users` in synthetic data generation
- Use smaller LSTM units

### Poor Prediction Accuracy
- Increase training data (more users/days)
- Adjust model architecture
- Check feature normalization
- Verify data preprocessing

### TFLite Conversion Errors
- Ensure TensorFlow version >= 2.15.0
- Check model input/output shapes
- Verify quantization calibration data

## Model Performance

- **Training Loss**: Typically < 0.1 (on log scale)
- **Validation Loss**: Similar to training loss
- **MAE**: Mean Absolute Error on validation set
- **Inference Time**: < 50ms on mobile devices
- **Model Size**: ~1-2 MB (quantized INT8)

## Next Steps

1. Train the model using the steps above
2. Copy model files to Flutter assets
3. Test predictions in the app
4. Fine-tune based on user feedback
5. Consider periodic retraining with new data

## Support

For issues or questions:
1. Check the README.md in this directory
2. Review error messages carefully
3. Verify all dependencies are installed
4. Ensure model files are in correct locations

