import json
import math
import random
import os

try:
    import numpy as np
    from hmmlearn import hmm
    HAS_HMMLEARN = True
except ImportError:
    HAS_HMMLEARN = False
    np = None


def generate_synthetic_data(n_sequences=100, seq_len=300):
    random.seed(42)
    np.random.seed(42)

    states = ['uptrend', 'downtrend', 'ranging']
    state_means = {
        'uptrend': [0.003, 0.015, 35.0],
        'downtrend': [-0.003, 0.015, 30.0],
        'ranging': [0.000, 0.006, 15.0],
    }
    state_stds = {
        'uptrend': [0.006, 0.003, 8.0],
        'downtrend': [0.006, 0.003, 8.0],
        'ranging': [0.003, 0.002, 5.0],
    }

    transitions = {
        'uptrend': {'uptrend': 0.70, 'downtrend': 0.10, 'ranging': 0.20},
        'downtrend': {'uptrend': 0.10, 'downtrend': 0.70, 'ranging': 0.20},
        'ranging': {'uptrend': 0.25, 'downtrend': 0.25, 'ranging': 0.50},
    }

    all_features = []
    for _ in range(n_sequences):
        current = 'ranging'
        seq = []
        for _ in range(seq_len):
            m = state_means[current]
            s = state_stds[current]
            ret = random.gauss(m[0], s[0])
            range_ratio = abs(random.gauss(m[1], s[1]))
            adx = max(0.0, random.gauss(m[2], s[2]))
            seq.append([ret, range_ratio, adx])
            r = random.random()
            cum = 0.0
            for nxt, p in transitions[current].items():
                cum += p
                if r <= cum:
                    current = nxt
                    break
        all_features.append(seq)

    return all_features


def load_real_data(filepath):
    with open(filepath, 'r') as f:
        data = json.load(f)
    sequences = []
    for seq in data:
        features = []
        for candle in seq:
            ret = candle.get('return', 0.0)
            range_ratio = candle.get('rangeRatio', candle.get('volatility', 0.0))
            adx = candle.get('adx', 15.0)
            features.append([ret, range_ratio, adx])
        if len(features) > 1:
            sequences.append(features)
    return sequences


def prepare_sequences(raw_sequences):
    prepared = []
    for seq in raw_sequences:
        arr = []
        for i in range(1, len(seq)):
            ret = seq[i][0]
            range_ratio = seq[i][1]
            adx = seq[i][2]
            arr.append([ret, range_ratio, adx])
        if arr:
            prepared.append(arr)
    return prepared


def train_hmm(sequences, n_states=3):
    if not HAS_HMMLEARN:
        raise RuntimeError("hmmlearn is required. Install with: pip install hmmlearn")

    lengths = [len(s) for s in sequences]
    X = np.vstack(sequences)

    best_model = None
    best_score = float('-inf')
    for seed in range(10):
        model = hmm.GaussianHMM(
            n_components=n_states,
            covariance_type='diag',
            n_iter=500,
            min_covar=0.01,
            random_state=seed,
        )
        model.fit(X, lengths=lengths)
        score = model.score(X, lengths=lengths)
        if score > best_score:
            best_score = score
            best_model = model
    model = best_model

    means = model.means_.tolist()
    diag_vars = np.diagonal(model.covars_, axis1=1, axis2=2).tolist()

    state_map = None
    if means is not None and len(means) == n_states:
        adx_vals = [m[2] for m in means]
        sorted_by_adx = sorted(range(len(adx_vals)), key=lambda i: adx_vals[i])
        ranging_idx = sorted_by_adx[0]
        remaining = [sorted_by_adx[1], sorted_by_adx[2]]
        if means[remaining[0]][0] >= means[remaining[1]][0]:
            uptrend_idx, downtrend_idx = remaining[0], remaining[1]
        else:
            uptrend_idx, downtrend_idx = remaining[1], remaining[0]
        state_map = {
            uptrend_idx: 'uptrend',
            downtrend_idx: 'downtrend',
            ranging_idx: 'ranging',
        }

    desired_order = ['uptrend', 'downtrend', 'ranging']
    if state_map:
        reorder = sorted(range(n_states), key=lambda i: desired_order.index(state_map[i]))
    else:
        reorder = list(range(n_states))

    states = [desired_order[i] for i in range(n_states)]
    means = [means[i] for i in reorder]
    diag_vars = [diag_vars[i] for i in reorder]
    transition_matrix = [[model.transmat_[reorder[i]][reorder[j]] for j in range(n_states)] for i in range(n_states)]
    initial_probabilities = [model.startprob_[i] for i in reorder]

    return {
        'states': states,
        'means': means,
        'variances': diag_vars,
        'transitionMatrix': transition_matrix,
        'initialProbabilities': initial_probabilities,
    }


def export_params(params, output_path):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w') as f:
        json.dump(params, f, indent=2)
    print(f"Exported HMM parameters to {output_path}")


def main():
    data_file = os.environ.get('HMM_DATA_FILE')
    if data_file and os.path.exists(data_file):
        print(f"Loading real data from {data_file}")
        raw = load_real_data(data_file)
    else:
        print("No real data file provided, generating synthetic data")
        raw = generate_synthetic_data()

    sequences = prepare_sequences(raw)
    if not sequences:
        raise ValueError("No valid sequences prepared")

    params = train_hmm(sequences, n_states=3)
    export_params(params, 'assets/hmm_regime_params.json')

    print("Training complete.")
    print("States:", params['states'])
    print("Means:")
    for s, m in zip(params['states'], params['means']):
        print(f"  {s}: ret={m[0]:.6f}, rangeRatio={m[1]:.6f}, adx={m[2]:.2f}")
    print("Transition matrix:")
    for row in params['transitionMatrix']:
        print(['%.2f' % v for v in row])


if __name__ == '__main__':
    main()

