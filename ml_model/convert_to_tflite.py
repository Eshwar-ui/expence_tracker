"""
Convert trained TensorFlow model to TensorFlow Lite format
Optimized for mobile deployment
"""

import tensorflow as tf
import numpy as np
import os
import json


def convert_to_tflite(
    model_path: str,
    output_path: str = 'models/expense_predictor.tflite',
    quantize: bool = True,
    representative_dataset_size: int = 100
):
    """
    Convert Keras model to TensorFlow Lite format
    
    Args:
        model_path: Path to saved Keras model (.h5)
        output_path: Output path for TFLite model
        quantize: Whether to apply INT8 quantization
        representative_dataset_size: Number of samples for quantization calibration
    """
    print("=" * 60)
    print("TensorFlow Lite Conversion")
    print("=" * 60)
    
    # Load model
    print(f"\n1. Loading model from {model_path}...")
    model = tf.keras.models.load_model(model_path)
    print(f"   Model loaded successfully")
    
    # Get model input shape
    input_shape = model.input_shape[1:]  # Remove batch dimension
    print(f"   Input shape: {input_shape}")
    print(f"   Output shape: {model.output_shape[1:]}")
    
    # Convert to TensorFlow Lite
    print("\n2. Converting to TensorFlow Lite...")
    
    if quantize:
        # Quantization-aware conversion
        print("   Using INT8 quantization for mobile optimization...")
        
        # Create representative dataset
        def representative_dataset():
            for _ in range(representative_dataset_size):
                # Generate random input matching model input shape
                yield [np.random.randn(1, *input_shape).astype(np.float32)]
        
        # Convert with quantization
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = representative_dataset
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.int8
        converter.inference_output_type = tf.int8
        
        tflite_model = converter.convert()
    else:
        # Standard conversion (float32)
        print("   Using float32 precision...")
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
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
    
    print(f"   Input details: {input_details[0]}")
    print(f"   Output details: {output_details[0]}")
    
    # Test inference
    test_input = np.random.randn(1, *input_shape).astype(np.float32)
    
    if quantize:
        # For quantized models, convert input to int8
        input_scale, input_zero_point = input_details[0]['quantization']
        test_input_quantized = (test_input / input_scale + input_zero_point).astype(np.int8)
        interpreter.set_tensor(input_details[0]['index'], test_input_quantized)
    else:
        interpreter.set_tensor(input_details[0]['index'], test_input)
    
    interpreter.invoke()
    
    output = interpreter.get_tensor(output_details[0]['index'])
    
    if quantize:
        # Dequantize output
        output_scale, output_zero_point = output_details[0]['quantization']
        output = (output.astype(np.float32) - output_zero_point) * output_scale
    
    print(f"   Test input shape: {test_input.shape}")
    print(f"   Test output shape: {output.shape}")
    print(f"   Sample output (first 5 values): {output[0][:5]}")
    
    print("\n" + "=" * 60)
    print("TFLite conversion completed successfully!")
    print("=" * 60)
    
    return output_path, model_size_mb


def create_model_metadata(
    stats_path: str,
    tflite_path: str,
    output_path: str = 'models/model_metadata.json'
):
    """
    Create metadata file for the TFLite model
    
    Args:
        stats_path: Path to model stats JSON
        tflite_path: Path to TFLite model
        output_path: Output path for metadata
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
    }
    
    with open(output_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"Metadata saved to {output_path}")
    return metadata


if __name__ == '__main__':
    from datetime import datetime
    
    # Convert model
    model_path = 'models/expense_predictor.h5'
    
    if not os.path.exists(model_path):
        print(f"Error: Model file not found at {model_path}")
        print("Please train the model first using train_model.py")
    else:
        tflite_path, model_size = convert_to_tflite(
            model_path=model_path,
            output_path='models/expense_predictor.tflite',
            quantize=True,
            representative_dataset_size=100
        )
        
        # Create metadata
        stats_path = model_path.replace('.h5', '_stats.json')
        if os.path.exists(stats_path):
            create_model_metadata(stats_path, tflite_path)

