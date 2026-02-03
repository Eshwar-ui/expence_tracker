"""
Data Preprocessing for Expense Prediction Model
Handles feature engineering and data preparation
"""

import numpy as np
import pandas as pd
from typing import List, Tuple, Dict
from datetime import datetime, timedelta
import json


class ExpenseDataPreprocessor:
    """Preprocesses expense data for ML model training"""
    
    def __init__(self, sequence_length: int = 30, prediction_horizon: int = 30):
        """
        Args:
            sequence_length: Number of days to use as input sequence
            prediction_horizon: Number of days to predict ahead
        """
        self.sequence_length = sequence_length
        self.prediction_horizon = prediction_horizon
        self.category_encoder = {}
        self.amount_scaler = None
        self.feature_stats = {}
    
    def prepare_features(self, expenses: List[Dict]) -> Tuple[np.ndarray, np.ndarray]:
        """
        Convert expense list to feature arrays
        
        Args:
            expenses: List of expense dictionaries with keys:
                - amount: float
                - date: datetime or ISO string
                - category: string
                - type: 'expense' or 'income'
        
        Returns:
            X: Feature array of shape (samples, sequence_length, features)
            y: Target array of shape (samples, prediction_horizon, outputs)
        """
        # Convert to DataFrame
        df = pd.DataFrame(expenses)
        df['date'] = pd.to_datetime(df['date'])
        df = df.sort_values('date')
        
        # Filter only expenses (not income)
        df = df[df['type'] == 'expense'].copy()
        
        # Create daily aggregated data
        daily_data = self._create_daily_aggregates(df)
        
        # Extract features
        X, y = self._create_sequences(daily_data)
        
        return X, y
    
    def _create_daily_aggregates(self, df: pd.DataFrame) -> pd.DataFrame:
        """Aggregate expenses by day and create features"""
        # Set date as index
        df = df.set_index('date')
        
        # Get date range
        start_date = df.index.min()
        end_date = df.index.max()
        date_range = pd.date_range(start=start_date, end=end_date, freq='D')
        
        # Create daily aggregates
        daily_data = []
        
        for date in date_range:
            day_expenses = df[df.index.date == date.date()]
            
            # Daily total
            daily_total = day_expenses['amount'].sum() if len(day_expenses) > 0 else 0.0
            
            # Category breakdown (top categories)
            category_totals = day_expenses.groupby('category')['amount'].sum().to_dict()
            
            # Number of transactions
            num_transactions = len(day_expenses)
            
            # Day of week (0=Monday, 6=Sunday)
            day_of_week = date.weekday()
            
            # Day of month (1-31)
            day_of_month = date.day
            
            # Is weekend
            is_weekend = 1 if day_of_week >= 5 else 0
            
            # Is month end (last 3 days)
            is_month_end = 1 if date.day >= 28 else 0
            
            # Is month start (first 5 days)
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
        
        return pd.DataFrame(daily_data)
    
    def _create_sequences(self, daily_data: pd.DataFrame) -> Tuple[np.ndarray, np.ndarray]:
        """Create sequences for time series prediction"""
        sequences = []
        targets = []
        
        # Get unique categories
        all_categories = set()
        for cats in daily_data['category_totals']:
            all_categories.update(cats.keys())
        all_categories = sorted(list(all_categories))
        
        # Limit to top 10 categories for model size
        category_totals_all = {}
        for cats in daily_data['category_totals']:
            for cat, amount in cats.items():
                category_totals_all[cat] = category_totals_all.get(cat, 0) + amount
        
        top_categories = sorted(
            category_totals_all.items(),
            key=lambda x: x[1],
            reverse=True
        )[:10]
        top_categories = [cat for cat, _ in top_categories]
        
        # Create sequences
        for i in range(len(daily_data) - self.sequence_length - self.prediction_horizon + 1):
            # Input sequence
            seq_data = daily_data.iloc[i:i + self.sequence_length]
            
            # Target sequence
            target_data = daily_data.iloc[
                i + self.sequence_length:i + self.sequence_length + self.prediction_horizon
            ]
            
            # Extract features for input sequence
            features = []
            for _, row in seq_data.iterrows():
                feature_vector = [
                    row['daily_total'],
                    row['num_transactions'],
                    row['day_of_week'] / 6.0,  # Normalize 0-1
                    row['day_of_month'] / 31.0,  # Normalize 0-1
                    row['is_weekend'],
                    row['is_month_end'],
                    row['is_month_start'],
                ]
                
                # Add category features (top 10)
                for cat in top_categories:
                    feature_vector.append(row['category_totals'].get(cat, 0.0))
                
                features.append(feature_vector)
            
            sequences.append(features)
            
            # Extract targets (daily totals for prediction horizon)
            target_vector = target_data['daily_total'].values.tolist()
            targets.append(target_vector)
        
        X = np.array(sequences, dtype=np.float32)
        y = np.array(targets, dtype=np.float32)
        
        # Store feature stats for normalization
        self.feature_stats = {
            'mean': np.mean(X),
            'std': np.std(X),
            'categories': top_categories,
        }
        
        # Normalize features
        X = (X - self.feature_stats['mean']) / (self.feature_stats['std'] + 1e-8)
        
        # Normalize targets (log scale for better training)
        y = np.log1p(y)  # log(1 + x) to handle zeros
        
        return X, y
    
    def preprocess_for_inference(
        self,
        expenses: List[Dict],
        categories: List[str]
    ) -> np.ndarray:
        """
        Preprocess expense data for inference (single prediction)
        
        Args:
            expenses: List of recent expenses
            categories: List of category names used in training
        
        Returns:
            Feature array of shape (1, sequence_length, features)
        """
        X, _ = self.prepare_features(expenses)
        
        if len(X) == 0:
            # Return zeros if not enough data
            return np.zeros((1, self.sequence_length, 7 + len(categories)), dtype=np.float32)
        
        # Use the most recent sequence
        return X[-1:]


def generate_synthetic_data(num_users: int = 100, days_per_user: int = 180) -> List[Dict]:
    """
    Generate synthetic expense data for training
    
    Args:
        num_users: Number of synthetic users
        days_per_user: Number of days of data per user
    
    Returns:
        List of expense dictionaries
    """
    np.random.seed(42)
    expenses = []
    
    categories = [
        'Food & Dining', 'Transportation', 'Shopping', 'Entertainment',
        'Bills & Utilities', 'Healthcare', 'Education', 'Travel',
        'Personal Care', 'Subscriptions', 'Insurance', 'Other'
    ]
    
    base_date = datetime.now() - timedelta(days=days_per_user)
    
    for user_id in range(num_users):
        # User-specific spending patterns
        base_daily_spend = np.random.uniform(200, 1000)
        category_weights = np.random.dirichlet(np.ones(len(categories)))
        
        for day_offset in range(days_per_user):
            date = base_date + timedelta(days=day_offset)
            
            # Day of week effect (weekends higher spending)
            day_factor = 1.2 if date.weekday() >= 5 else 1.0
            
            # Month end effect (higher spending)
            month_end_factor = 1.3 if date.day >= 28 else 1.0
            
            # Random variation
            daily_total = base_daily_spend * day_factor * month_end_factor * np.random.uniform(0.5, 1.5)
            
            # Number of transactions per day
            num_transactions = np.random.poisson(3)
            
            # Distribute across categories
            remaining = daily_total
            for i, category in enumerate(categories[:-1]):  # Exclude 'Other'
                if remaining <= 0:
                    break
                
                # Probability of transaction in this category
                if np.random.random() < category_weights[i]:
                    amount = min(remaining, np.random.uniform(50, daily_total * category_weights[i] * 2))
                    remaining -= amount
                    
                    expenses.append({
                        'amount': amount,
                        'date': date.isoformat(),
                        'category': category,
                        'type': 'expense',
                        'title': f'{category} transaction',
                        'description': '',
                    })
            
            # Add remaining to 'Other'
            if remaining > 0:
                expenses.append({
                    'amount': remaining,
                    'date': date.isoformat(),
                    'category': 'Other',
                    'type': 'expense',
                    'title': 'Other transaction',
                    'description': '',
                })
    
    return expenses


if __name__ == '__main__':
    # Test data generation
    print("Generating synthetic data...")
    synthetic_data = generate_synthetic_data(num_users=10, days_per_user=90)
    print(f"Generated {len(synthetic_data)} expenses")
    
    # Test preprocessing
    print("\nTesting preprocessing...")
    preprocessor = ExpenseDataPreprocessor(sequence_length=30, prediction_horizon=30)
    X, y = preprocessor.prepare_features(synthetic_data)
    print(f"X shape: {X.shape}")
    print(f"y shape: {y.shape}")
    print(f"Feature stats: {preprocessor.feature_stats}")

