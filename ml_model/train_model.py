"""
Main training script for Expense Prediction Model
"""

import numpy as np
import tensorflow as tf
from datetime import datetime
import os
import json
from data_preprocessor import ExpenseDataPreprocessor, generate_synthetic_data
from model_architecture import create_expense_prediction_model, get_model_summary


def train_model(
    num_epochs: int = 50,
    batch_size: int = 32,
    validation_split: int = 0.2,
    sequence_length: int = 30,
    prediction_horizon: int = 30,
    save_path: str = 'models/expense_predictor.h5'
):
    """
    Train the expense prediction model
    
    Args:
        num_epochs: Number of training epochs
        batch_size: Batch size for training
        validation_split: Fraction of data to use for validation
        sequence_length: Input sequence length
        prediction_horizon: Prediction horizon
        save_path: Path to save trained model
    """
    print("=" * 60)
    print("Expense Prediction Model Training")
    print("=" * 60)
    
    # Set random seeds for reproducibility
    np.random.seed(42)
    tf.random.set_seed(42)
    
    # Generate synthetic training data
    print("\n1. Generating synthetic training data...")
    synthetic_data = generate_synthetic_data(num_users=200, days_per_user=180)
    print(f"   Generated {len(synthetic_data)} expense records")
    
    # Preprocess data
    print("\n2. Preprocessing data...")
    preprocessor = ExpenseDataPreprocessor(
        sequence_length=sequence_length,
        prediction_horizon=prediction_horizon
    )
    X, y = preprocessor.prepare_features(synthetic_data)
    print(f"   Input shape: {X.shape}")
    print(f"   Output shape: {y.shape}")
    
    # Split data
    split_idx = int(len(X) * (1 - validation_split))
    X_train, X_val = X[:split_idx], X[split_idx:]
    y_train, y_val = y[:split_idx], y[split_idx:]
    
    print(f"   Training samples: {len(X_train)}")
    print(f"   Validation samples: {len(X_val)}")
    
    # Create model
    print("\n3. Creating model architecture...")
    num_features = X.shape[2]
    model = create_expense_prediction_model(
        sequence_length=sequence_length,
        num_features=num_features,
        prediction_horizon=prediction_horizon,
        lstm_units=64,
        dense_units=[128, 64, 32]
    )
    get_model_summary(model)
    
    # Callbacks
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=10,
            restore_best_weights=True,
            verbose=1
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-6,
            verbose=1
        ),
        keras.callbacks.ModelCheckpoint(
            filepath=save_path.replace('.h5', '_best.h5'),
            monitor='val_loss',
            save_best_only=True,
            verbose=1
        )
    ]
    
    # Train model
    print("\n4. Training model...")
    history = model.fit(
        X_train, y_train,
        batch_size=batch_size,
        epochs=num_epochs,
        validation_data=(X_val, y_val),
        callbacks=callbacks,
        verbose=1
    )
    
    # Save model
    print(f"\n5. Saving model to {save_path}...")
    os.makedirs(os.path.dirname(save_path), exist_ok=True)
    model.save(save_path)
    
    # Save preprocessor stats
    stats_path = save_path.replace('.h5', '_stats.json')
    stats = {
        'sequence_length': sequence_length,
        'prediction_horizon': prediction_horizon,
        'num_features': num_features,
        'feature_stats': {
            'mean': float(preprocessor.feature_stats['mean']),
            'std': float(preprocessor.feature_stats['std']),
            'categories': preprocessor.feature_stats['categories']
        }
    }
    
    with open(stats_path, 'w') as f:
        json.dump(stats, f, indent=2)
    
    print(f"   Model saved to {save_path}")
    print(f"   Stats saved to {stats_path}")
    
    # Evaluate model
    print("\n6. Evaluating model...")
    train_loss = model.evaluate(X_train, y_train, verbose=0)
    val_loss = model.evaluate(X_val, y_val, verbose=0)
    
    print(f"   Training Loss: {train_loss[0]:.4f}, MAE: {train_loss[1]:.4f}")
    print(f"   Validation Loss: {val_loss[0]:.4f}, MAE: {val_loss[1]:.4f}")
    
    # Test prediction
    print("\n7. Testing prediction...")
    sample_idx = np.random.randint(0, len(X_val))
    sample_input = X_val[sample_idx:sample_idx+1]
    sample_target = y_val[sample_idx]
    prediction = model.predict(sample_input, verbose=0)[0]
    
    print(f"   Sample input shape: {sample_input.shape}")
    print(f"   Predicted (first 5 days): {np.expm1(prediction[:5])}")
    print(f"   Actual (first 5 days): {np.expm1(sample_target[:5])}")
    
    print("\n" + "=" * 60)
    print("Training completed successfully!")
    print("=" * 60)
    
    return model, preprocessor, history


if __name__ == '__main__':
    import tensorflow.keras as keras
    
    # Train model
    model, preprocessor, history = train_model(
        num_epochs=50,
        batch_size=32,
        validation_split=0.2,
        sequence_length=30,
        prediction_horizon=30,
        save_path='models/expense_predictor.h5'
    )

