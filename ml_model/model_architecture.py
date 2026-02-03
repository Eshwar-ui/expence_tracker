"""
Neural Network Architecture for Expense Prediction
Uses LSTM for time series patterns and Dense layers for predictions
"""

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from typing import Tuple


def create_expense_prediction_model(
    sequence_length: int = 30,
    num_features: int = 17,
    prediction_horizon: int = 30,
    lstm_units: int = 64,
    dense_units: List[int] = [128, 64, 32]
) -> keras.Model:
    """
    Create LSTM-based model for expense prediction
    
    Args:
        sequence_length: Length of input sequence (days)
        num_features: Number of features per time step
        prediction_horizon: Number of days to predict
        lstm_units: Number of LSTM units
        dense_units: List of dense layer sizes
    
    Returns:
        Compiled Keras model
    """
    # Input layer
    inputs = keras.Input(shape=(sequence_length, num_features), name='expense_sequence')
    
    # LSTM layers for temporal patterns
    x = layers.LSTM(
        lstm_units,
        return_sequences=True,
        dropout=0.2,
        recurrent_dropout=0.2,
        name='lstm_1'
    )(inputs)
    
    x = layers.LSTM(
        lstm_units // 2,
        return_sequences=False,
        dropout=0.2,
        recurrent_dropout=0.2,
        name='lstm_2'
    )(x)
    
    # Dense layers for prediction
    for i, units in enumerate(dense_units):
        x = layers.Dense(units, activation='relu', name=f'dense_{i+1}')(x)
        x = layers.Dropout(0.3, name=f'dropout_{i+1}')(x)
        x = layers.BatchNormalization(name=f'batch_norm_{i+1}')(x)
    
    # Output layer - predict daily spending for next N days
    outputs = layers.Dense(
        prediction_horizon,
        activation='relu',  # Spending is always >= 0
        name='daily_predictions'
    )(x)
    
    # Create model
    model = keras.Model(inputs=inputs, outputs=outputs, name='expense_predictor')
    
    # Compile model
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='mse',  # Mean Squared Error for regression
        metrics=['mae', 'mape']  # Mean Absolute Error, Mean Absolute Percentage Error
    )
    
    return model


def create_multi_output_model(
    sequence_length: int = 30,
    num_features: int = 17,
    prediction_horizon: int = 30,
    num_categories: int = 10,
    lstm_units: int = 64
) -> keras.Model:
    """
    Create multi-output model that predicts:
    1. Daily spending totals
    2. Category-wise spending
    3. Anomaly score
    
    Args:
        sequence_length: Length of input sequence
        num_features: Number of features per time step
        prediction_horizon: Number of days to predict
        num_categories: Number of expense categories
        lstm_units: Number of LSTM units
    
    Returns:
        Compiled Keras model with multiple outputs
    """
    # Input layer
    inputs = keras.Input(shape=(sequence_length, num_features), name='expense_sequence')
    
    # Shared LSTM layers
    x = layers.LSTM(
        lstm_units,
        return_sequences=True,
        dropout=0.2,
        name='lstm_1'
    )(inputs)
    
    x = layers.LSTM(
        lstm_units // 2,
        return_sequences=False,
        dropout=0.2,
        name='lstm_2'
    )(x)
    
    # Shared dense layers
    shared = layers.Dense(128, activation='relu', name='shared_dense_1')(x)
    shared = layers.Dropout(0.3)(shared)
    shared = layers.Dense(64, activation='relu', name='shared_dense_2')(shared)
    
    # Output 1: Daily spending totals
    daily_output = layers.Dense(
        prediction_horizon,
        activation='relu',
        name='daily_totals'
    )(shared)
    
    # Output 2: Category-wise spending (for next month total)
    category_output = layers.Dense(
        num_categories,
        activation='softmax',  # Probabilities across categories
        name='category_distribution'
    )(shared)
    
    # Output 3: Anomaly score (0-1, higher = more anomalous)
    anomaly_output = layers.Dense(
        1,
        activation='sigmoid',
        name='anomaly_score'
    )(shared)
    
    # Create model
    model = keras.Model(
        inputs=inputs,
        outputs=[daily_output, category_output, anomaly_output],
        name='multi_output_expense_predictor'
    )
    
    # Compile with multiple losses
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss={
            'daily_totals': 'mse',
            'category_distribution': 'categorical_crossentropy',
            'anomaly_score': 'binary_crossentropy'
        },
        loss_weights={
            'daily_totals': 1.0,
            'category_distribution': 0.5,
            'anomaly_score': 0.3
        },
        metrics={
            'daily_totals': ['mae', 'mape'],
            'category_distribution': 'accuracy',
            'anomaly_score': 'binary_accuracy'
        }
    )
    
    return model


def get_model_summary(model: keras.Model):
    """Print model summary"""
    model.summary()
    
    # Calculate model size
    total_params = model.count_params()
    trainable_params = sum([tf.size(w).numpy() for w in model.trainable_weights])
    
    print(f"\nTotal parameters: {total_params:,}")
    print(f"Trainable parameters: {trainable_params:,}")
    print(f"Non-trainable parameters: {total_params - trainable_params:,}")


if __name__ == '__main__':
    # Test model creation
    print("Creating expense prediction model...")
    model = create_expense_prediction_model(
        sequence_length=30,
        num_features=17,
        prediction_horizon=30
    )
    get_model_summary(model)
    
    # Test with dummy data
    print("\nTesting with dummy data...")
    dummy_input = tf.random.normal((1, 30, 17))
    prediction = model.predict(dummy_input, verbose=0)
    print(f"Input shape: {dummy_input.shape}")
    print(f"Output shape: {prediction.shape}")
    print(f"Sample prediction: {prediction[0][:5]}")

