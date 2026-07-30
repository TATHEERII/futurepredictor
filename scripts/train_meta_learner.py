import json
import os
import random

try:
    import numpy as np
    from sklearn.linear_model import LogisticRegression
    HAS_SKLEARN = True
except ImportError:
    HAS_SKLEARN = False
    np = None


FEATURE_NAMES = [
    'indicatorConfidence',
    'mlProbUp',
    'mlProbDown',
    'mlProbSideways',
    'regimeProbTrending',
    'regimeProbRanging',
    'regimeProbCrisis',
]


def generate_synthetic_meta_data(n_samples=5000):
    random.seed(42)
    np.random.seed(42)

    X = []
    y = []

    for _ in range(n_samples):
        indicator_conf = random.uniform(0.4, 1.0)

        regime_t = random.uniform(0.0, 1.0)
        regime_r = random.uniform(0.0, 1.0) * (1 - regime_t)
        regime_c = 1 - regime_t - regime_r

        if regime_t > 0.5:
            ml_up = random.uniform(0.5, 0.95)
            ml_down = random.uniform(0.0, 0.3)
            ml_side = 1.0 - ml_up - ml_down
        elif regime_r > 0.5:
            ml_up = random.uniform(0.2, 0.5)
            ml_down = random.uniform(0.2, 0.5)
            ml_side = 1.0 - ml_up - ml_down
        else:
            ml_up = random.uniform(0.3, 0.7)
            ml_down = random.uniform(0.3, 0.7)
            ml_side = max(0.0, 1.0 - ml_up - ml_down)

        agreement = indicator_conf * (ml_up + ml_down) * regime_t

        noise = random.gauss(0, 0.15)
        label = 1 if (agreement + noise) > 0.35 else 0

        X.append([indicator_conf, ml_up, ml_down, ml_side, regime_t, regime_r, regime_c])
        y.append(label)

    return np.array(X), np.array(y)


def train_meta_learner(X, y):
    if not HAS_SKLEARN:
        raise RuntimeError("scikit-learn is required. Install with: pip install scikit-learn")

    model = LogisticRegression(
        C=1.0,
        solver='lbfgs',
        max_iter=1000,
        random_state=42,
    )
    model.fit(X, y)
    return model


def export_params(model, X, y, output_path):
    weights = model.coef_[0].tolist()
    bias = float(model.intercept_[0])
    os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)
    params = {
        'featureNames': FEATURE_NAMES,
        'weights': weights,
        'bias': bias,
        'version': '1.0.0',
    }
    with open(output_path, 'w') as f:
        json.dump(params, f, indent=2)
    print(f"Exported meta-learner parameters to {output_path}")
    print(f"Weights: {[round(w, 4) for w in weights]}")
    print(f"Bias: {bias:.6f}")
    print(f"Training accuracy: {model.score(X, y):.4f}")


def main():
    X, y = generate_synthetic_meta_data(n_samples=5000)
    model = train_meta_learner(X, y)
    export_params(model, X, y, 'assets/meta_learner_params.json')
    print("Meta-learner training complete.")


if __name__ == '__main__':
    main()
