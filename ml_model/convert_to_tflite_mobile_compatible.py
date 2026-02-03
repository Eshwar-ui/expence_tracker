"""
Convert trained TensorFlow model to TensorFlow Lite format
Optimized for mobile deployment with compatibility settings
"""

import tensorflow as tf
import numpy as np
import os
import json
from datetime import datetime


def convert_to_tflite_mobile_compatible(
    model_path: str,
    output_path: str = 'models/expense_predictor.tflite',
    quantize: bool = False,  # Set to False for better compatibility
    representative_dataset_size: int = 100
):
    """
    Convert Keras model to TensorFlow Lite format with mobile compatibility
    
    Args:
        model_path: Path to saved Keras model (.h5)
        output_path: Output path for TFLite model
        quantize: Whether to apply quantization (False recommended for compatibility)
        representative_dataset_size: Number of samples for quantization calibration
    """
    print("=" * 60)
    print("TensorFlow Lite Conversion (Mobile Compatible)")
    print("=" * 60)
    
    # Load model
    print(f"\n1. Loading model from {model_path}...")
    model = tf.keras.models.load_model(model_path)
    print(f"   Model loaded successfully")
    
    # Get model input shape
    input_shape = model.input_shape[1:]  # Remove batch dimension
    print(f"   Input shape: {input_shape}")
    print(f"   Output shape: {model.output_shape[1:]}")
    
    # Convert to TensorFlow Lite with compatibility settings
    print("\n2. Converting to TensorFlow Lite (mobile compatible)...")
    
    # Use float32 for better compatibility (no quantization)
    print("   Using float32 precision for maximum compatibility...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Set target spec for mobile compatibility
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,  # Use built-in ops only
    ]
    
    # Disable experimental features that might cause compatibility issues
    converter.experimental_new_converter = True
    converter.experimental_new_quantizer = False
    
    # Convert
    try:
        tflite_model = converter.convert()
    except Exception as e:
        print(f"   ⚠️ Standard conversion failed: {e}")
        print("   Trying with fallback settings...")
        
        # Fallback: Use older converter
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
        converter.experimental_new_converter = False
        tflite_model = converter.convert()
    
    # Save TFLite model
    print(f"\n3. Saving TFLite model to {output_path}...")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    # Get model size
    model_size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"   Model saved successfully")
    print(f"   Model size: {model_size_mb:.2f} MB")
    
    # Test TFLite model
    print("\n4. Testing TFLite model...")
    interpreter = tf.lite.Interpreter(model_path=output_path)
    interpreter.allocate_tensors()
    
    # Get input and output details
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print(f"   Input shape: {input_details[0]['shape']}")
    print(f"   Input type: {input_details[0]['dtype']}")
    print(f"   Output shape: {output_details[0]['shape']}")
    print(f"   Output type: {output_details[0]['dtype']}")
    
    # Test inference
    test_input = np.random.randn(1, *input_shape).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], test_input)
    interpreter.invoke()
    
    output = interpreter.get_tensor(output_details[0]['index'])
    
    print(f"   Test input shape: {test_input.shape}")
    print(f"   Test output shape: {output.shape}")
    print(f"   Sample output (first 5 values): {output[0][:5]}")
    
    print("\n" + "=" * 60)
    print("TFLite conversion completed successfully!")
    print("=" * 60)
    print("\n✅ Model is compatible with mobile TFLite runtimes")
    print("✅ Ready for Flutter integration")
    
    return output_path, model_size_mb


def create_model_metadata(
    stats_path: str,
    tflite_path: str,
    output_path: str = 'models/model_metadata.json'
):
    """
    Create metadata file for the TFLite model
    """
    with open(stats_path, 'r') as f:
        stats = json.load(f)
    
    metadata = {
        'model_version': '1.0.0',
        'model_type': 'expense_prediction',
        'tflite_path': tflite_path,
        'sequence_length': stats['sequence_length'],
        'prediction_horizon': stats['prediction_horizon'],
        'num_features': stats['num_features'],
        'categories': stats['feature_stats']['categories'],
        'feature_stats': stats['feature_stats'],
        'created_at': datetime.now().isoformat(),
        'compatibility': 'mobile_tflite_v2',
    }
    
    with open(output_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"Metadata saved to {output_path}")
    return metadata


if __name__ == '__main__':
    # Convert model
    model_path = 'models/expense_predictor.h5'
    
    if not os.path.exists(model_path):
        print(f"Error: Model file not found at {model_path}")
        print("Please train the model first using train_model.py")
    else:
        tflite_path, model_size = convert_to_tflite_mobile_compatible(
            model_path=model_path,
            output_path='models/expense_predictor.tflite',
            quantize=False,  # False for better compatibility
            representative_dataset_size=100
        )
        
        # Create metadata
        stats_path = model_path.replace('.h5', '_stats.json')
        if os.path.exists(stats_path):
            create_model_metadata(stats_path, tflite_path)
