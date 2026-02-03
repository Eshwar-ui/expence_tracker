# AI Model Files

This directory should contain the trained TensorFlow Lite model files.

## Required Files

1. **expense_predictor.tflite** - The trained TensorFlow Lite model
2. **expense_predictor_stats.json** - Model metadata and feature statistics

## How to Generate Model Files

1. **Install Python dependencies**:
   ```bash
   cd ml_model
   pip install -r requirements.txt
   ```

2. **Train the model**:
   ```bash
   python train_model.py
   ```
   This will create:
   - `models/expense_predictor.h5` (Keras model)
   - `models/expense_predictor_stats.json` (metadata)

3. **Convert to TensorFlow Lite**:
   ```bash
   python convert_to_tflite.py
   ```
   This will create:
   - `models/expense_predictor.tflite` (TFLite model)

4. **Copy files to Flutter assets**:
   ```bash
   # Copy TFLite model
   cp ml_model/models/expense_predictor.tflite assets/models/
   
   # Copy metadata
   cp ml_model/models/expense_predictor_stats.json assets/models/
   ```

## Model Specifications

- **Input**: 30 days of expense data (17 features per day)
- **Output**: 30 days of predicted daily spending
- **Size**: ~1-2 MB (quantized INT8)
- **Format**: TensorFlow Lite

## Note

If the model files are not present, the AI prediction feature will gracefully degrade and show a message that the model needs to be trained first.

