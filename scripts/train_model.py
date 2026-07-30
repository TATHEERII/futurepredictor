import json
import os
import math
import random
import argparse
from datetime import datetime, timezone

try:
    import numpy as np
    import pandas as pd
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False
    np = None

try:
    import xgboost as xgb
    HAS_XGB = True
except ImportError:
    HAS_XGB = False

try:
    import lightgbm as lgb
    HAS_LGB = False
except ImportError:
    try:
        import lightgbm as lgb
        HAS_LGB = True
    except ImportError:
        HAS_LGB = False

try:
    from sklearn.model_selection import TimeSeriesSplit
    from sklearn.metrics import log_loss, brier_score_loss
    HAS_SKLEARN = True
except ImportError:
    HAS_SKLEARN = False

try:
    import onnx
    import onnxruntime as ort
    HAS_ONNX = True
except ImportError:
    HAS_ONNX = False


def compute_ema(values, period):
    if len(values) < period:
        return values[:]
    result = []
    sma = sum(values[:period]) / period
    mult = 2.0 / (period + 1)
    for i, v in enumerate(values):
        if i < period:
            result.append(sma)
        else:
            ema = (v - result[-1]) * mult + result[-1] if i == period else (v - result[-1]) * mult + result[-1]
            result.append(ema)
    return result


def compute_sma(values, period):
    result = []
    for i in range(len(values)):
        if i < period - 1:
            result.append(sum(values[:i + 1]) / (i + 1))
        else:
            result.append(sum(values[i - period + 1:i + 1]) / period)
    return result


def compute_rsi(closes, period=14):
    result = [50.0] * len(closes)
    if len(closes) < period + 1:
        return result
    gains = []
    losses = []
    for i in range(1, len(closes)):
        diff = closes[i] - closes[i - 1]
        gains.append(diff if diff > 0 else 0.0)
        losses.append(-diff if diff < 0 else 0.0)
    avg_gain = sum(gains[:period]) / period
    avg_loss = sum(losses[:period]) / period
    if avg_loss == 0:
        result[period] = 100.0
    else:
        rs = avg_gain / avg_loss
        result[period] = 100.0 - (100.0 / (1.0 + rs))
    for i in range(period + 1, len(closes)):
        avg_gain = (avg_gain * (period - 1) + gains[i - 1]) / period
        avg_loss = (avg_loss * (period - 1) + losses[i - 1]) / period
        if avg_loss == 0:
            result[i] = 100.0
        else:
            rs = avg_gain / avg_loss
            result[i] = 100.0 - (100.0 / (1.0 + rs))
    return result


def compute_macd(closes, fast=12, slow=26, signal=9):
    ema_fast = compute_ema(closes, fast)
    ema_slow = compute_ema(closes, slow)
    macd_line = [f - s for f, s in zip(ema_fast, ema_slow)]
    macd_signal = compute_ema(macd_line, signal)
    macd_hist = [m - s for m, s in zip(macd_line, macd_signal)]
    return macd_line, macd_signal, macd_hist


def compute_bollinger(closes, period=20, std_dev=2.0):
    sma = compute_sma(closes, period)
    stds = []
    for i in range(len(closes)):
        if i < period - 1:
            stds.append(0.0)
        else:
            slice_ = closes[i - period + 1:i + 1]
            variance = sum((x - sma[i]) ** 2 for x in slice_) / period
            stds.append(math.sqrt(variance))
    upper = [s + d * std_dev for s, d in zip(sma, stds)]
    lower = [s - d * std_dev for s, d in zip(sma, stds)]
    return upper, lower, sma


def compute_atr(highs, lows, closes, period=14):
    trs = []
    for i in range(1, len(closes)):
        hl = highs[i] - lows[i]
        hc = abs(highs[i] - closes[i - 1])
        lc = abs(lows[i] - closes[i - 1])
        trs.append(max(hl, hc, lc))
    if len(trs) < period:
        return [0.0] * len(closes)
    atrs = [0.0] * len(closes)
    atr = sum(trs[:period]) / period
    atrs[period] = atr
    for i in range(period + 1, len(trs)):
        atr = (atr * (period - 1) + trs[i]) / period
        atrs[i] = atr
    return atrs


def compute_adx(highs, lows, closes, period=14):
    n = len(closes)
    if n < period + 1:
        return [0.0] * n, [False] * n, [0.0] * n, [0.0] * n
    plus_dms = []
    minus_dms = []
    trs = []
    for i in range(1, n):
        up = highs[i] - highs[i - 1]
        down = lows[i - 1] - lows[i]
        trs.append(max(highs[i] - lows[i], abs(highs[i] - closes[i - 1]), abs(lows[i] - closes[i - 1])))
        plus_dms.append(up if up > down and up > 0 else 0.0)
        minus_dms.append(down if down > up and down > 0 else 0.0)
    smoothed_pm = sum(plus_dms[:period])
    smoothed_nm = sum(minus_dms[:period])
    smoothed_tr = sum(trs[:period])
    adx_vals = []
    plus_dis = []
    minus_dis = []
    for i in range(period, len(trs)):
        smoothed_pm = smoothed_pm - (smoothed_pm / period) + plus_dms[i]
        smoothed_nm = smoothed_nm - (smoothed_nm / period) + minus_dms[i]
        smoothed_tr = smoothed_tr - (smoothed_tr / period) + trs[i]
        pd_ = smoothed_pm / smoothed_tr * 100 if smoothed_tr > 0 else 0
        md_ = smoothed_nm / smoothed_tr * 100 if smoothed_tr > 0 else 0
        dx = abs(pd_ - md_) / (pd_ + md_) * 100 if (pd_ + md_) > 0 else 0
        adx_vals.append(dx)
        plus_dis.append(pd_)
        minus_dis.append(md_)
    if len(adx_vals) < 14:
        adx_smoothed = sum(adx_vals) / len(adx_vals) if adx_vals else 0
    else:
        adx_smoothed = sum(adx_vals[:14]) / 14
        for i in range(14, len(adx_vals)):
            adx_smoothed = (adx_smoothed * 13 + adx_vals[i]) / 14
    return adx_vals, plus_dis, minus_dis


def compute_volume_features(closes, volumes):
    vol_sma = compute_sma(volumes, 20)
    vol_rise = [0.0] * len(volumes)
    for i in range(len(volumes)):
        if vol_sma[i] > 0:
            vol_rise[i] = (volumes[i] - vol_sma[i]) / vol_sma[i]
    vroc = [0.0] * len(volumes)
    for i in range(14, len(volumes)):
        prev = volumes[i - 14]
        if prev > 0:
            vroc[i] = (volumes[i] - prev) / prev * 100
    return vol_rise, vroc


def compute_fibonacci_levels(high, low):
    diff = high - low
    return [high - diff * r for r in [0.236, 0.382, 0.5, 0.618]]


def compute_regime_features(closes, atrs, adxs, window=20):
    features = []
    for i in range(len(closes)):
        start = max(0, i - window)
        window_closes = closes[start:i + 1]
        window_atrs = atrs[start:i + 1]
        window_adxs = adxs[start:i + 1] if i < len(adxs) else [0] * (i - start + 1)
        if len(window_closes) < 2:
            features.append([0.0, 0.0, 15.0])
            continue
        ret = (window_closes[-1] - window_closes[0]) / window_closes[0] if window_closes[0] != 0 else 0.0
        vol = window_atrs[-1] / window_closes[-1] if window_closes[-1] != 0 else 0.0
        adx = window_adxs[-1] if window_adxs else 15.0
        features.append([ret, vol, adx])
    return features


def label_data(closes, forward_periods=6, buy_threshold=0.01, sell_threshold=-0.01):
    labels = []
    for i in range(len(closes)):
        future_idx = min(i + forward_periods, len(closes) - 1)
        forward_return = (closes[future_idx] - closes[i]) / closes[i] if closes[i] != 0 else 0.0
        if forward_return > buy_threshold:
            labels.append(0)
        elif forward_return < sell_threshold:
            labels.append(1)
        else:
            labels.append(2)
    return labels


def extract_features(row, idx, closes, highs, lows, volumes, emas, rsIs, macdHists, atrs,
                     bollinger_positions, adxs, plus_dis, minus_dis, vol_rises, vrocs,
                     fib_levels_list, support_levels, resistance_levels):
    features = []
    features.append(emas['short_aligned'][idx] if idx < len(emas['short_aligned']) else 0.5)
    features.append(emas['long_aligned'][idx] if idx < len(emas['long_aligned']) else 0.5)
    features.append(rsIs[idx] / 100.0 if idx < len(rsIs) else 0.5)
    features.append(macdHists[idx] / 100.0 if idx < len(macdHists) else 0.0)
    features.append(adxs[idx] / 50.0 if idx < len(adxs) else 0.0)
    features.append(vol_rises[idx] if idx < len(vol_rises) else 0.0)
    features.append(vrocs[idx] / 100.0 if idx < len(vrocs) else 0.5)
    features.append(bollinger_positions[idx] if idx < len(bollinger_positions) else 0.5)
    features.append(1.0 if idx > 0 and idx < len(closes) and closes[idx] > closes[idx - 1] else 0.0)
    features.append(1.0 if idx > 0 and idx < len(closes) and closes[idx] < closes[idx - 1] else 0.0)
    features.append(atrs[idx] / max(highs[idx] - lows[idx], 0.001) if idx < len(atrs) and idx < len(highs) and idx < len(lows) else 0.0)
    features.append(1.0 if idx < len(plus_dis) and idx < len(minus_dis) and plus_dis[idx] > minus_dis[idx] else 0.0)
    features.append(1.0 if idx < len(plus_dis) and idx < len(minus_dis) and plus_dis[idx] < minus_dis[idx] else 0.0)
    features.append((close - support_levels[idx]) / max(highs[idx] - lows[idx], 0.001) if idx < len(support_levels) and idx < len(highs) else 0.5)
    features.append((resistance_levels[idx] - close) / max(highs[idx] - lows[idx], 0.001) if idx < len(resistance_levels) and idx < len(highs) else 0.5)
    features.append(vol_rises[idx] * 10 if idx < len(vol_rises) else 0.0)
    return features


def load_klines(filepath):
    with open(filepath, 'r') as f:
        data = json.load(f)
    if isinstance(data, list) and len(data) > 0 and isinstance(data[0], list):
        rows = data
    elif isinstance(data, dict) and 'klines' in data:
        rows = data['klines']
    else:
        rows = data
    closes = []
    highs = []
    lows = []
    volumes = []
    for row in rows:
        if isinstance(row, list):
            closes.append(float(row[4]))
            highs.append(float(row[2]))
            lows.append(float(row[3]))
            volumes.append(float(row[5]))
        elif isinstance(row, dict):
            closes.append(float(row.get('close', row.get('c', 0))))
            highs.append(float(row.get('high', row.get('h', 0))))
            lows.append(float(row.get('low', row.get('l', 0))))
            volumes.append(float(row.get('volume', row.get('v', 0))))
    return closes, highs, lows, volumes


def train_walkforward(closes, highs, lows, volumes, n_splits=5, forward_periods=6):
    if len(closes) < 200:
        return None, None, []
    labels = label_data(closes, forward_periods=forward_periods)
    features_list = []
    for i in range(len(closes)):
        feature_row = _compute_feature_row(closes, highs, lows, volumes, i)
        features_list.append(feature_row)
    features = np.array(features_list)
    labels_arr = np.array(labels)
    train_indices = []
    test_indices = []
    fold_size = len(closes) // (n_splits + 1)
    for i in range(n_splits):
        test_start = fold_size * (i + 1)
        test_end = min(test_start + fold_size, len(closes))
        train_end = test_start
        train_idx = list(range(max(0, train_end - fold_size * i), train_end))
        test_idx = list(range(test_start, test_end))
        if len(train_idx) > 50 and len(test_idx) > 10:
            train_indices.append(train_idx)
            test_indices.append(test_idx)
    return features, labels_arr, list(zip(train_indices, test_indices))


def _compute_feature_row(closes, highs, lows, volumes, idx):
    window = min(idx + 1, 50)
    start = max(0, idx - window + 1)
    window_closes = closes[start:idx + 1]
    window_highs = highs[start:idx + 1]
    window_lows = lows[start:idx + 1]
    window_volumes = volumes[start:idx + 1]
    rsi_14 = compute_rsi(window_closes, 14)
    macd_line_, macd_signal_, macd_hist = compute_macd(window_closes)
    atr_vals = compute_atr(highs, lows, closes)
    upper, lower, mid = compute_bollinger(window_closes)
    ema_20 = compute_ema(window_closes, 20)
    ema_50 = compute_ema(window_closes, 50)
    vol_rise, vroc_ = compute_volume_features(window_closes, window_volumes)
    features = [
        ema_20[-1] / ema_50[-1] if len(ema_20) > 0 and ema_50[-1] != 0 else 1.0,
        ema_50[-1] / ema_20[-1] if len(ema_50) > 0 and ema_20[-1] != 0 else 1.0,
        rsi_14[-1] / 100.0 if rsi_14 else 0.5,
        macd_hist[-1] / 100.0 if macd_hist else 0.0,
        atr_vals[idx] / max(window_closes[-1], 0.001) if atr_vals[idx] > 0 else 0.0,
        (window_closes[-1] - mid[-1]) / (upper[-1] - lower[-1] + 1e-10) / 2.0 + 0.5,
        vol_rise[-1] if vol_rise else 0.0,
        (vroc_[-1] + 100) / 200.0 if vroc_ else 0.5,
        1.0 if len(window_closes) > 1 and window_closes[-1] > window_closes[-2] else 0.0,
        1.0 if len(window_closes) > 1 and window_closes[-1] < window_closes[-2] else 0.0,
        (highs[idx] - lows[idx]) / max(window_closes[-1], 0.001) if window_closes[-1] > 0 else 0.0,
        (highs[idx] - window_closes[-1]) / max(highs[idx] - lows[idx], 0.001) if highs[idx] != lows[idx] else 0.5,
        (window_closes[-1] - lows[idx]) / max(highs[idx] - lows[idx], 0.001) if highs[idx] != lows[idx] else 0.5,
    ]
    while len(features) < 33:
        features.append(0.0)
    return features[:33]


def train_model(closes, highs, lows, volumes, output_dir='.'):
    features, labels, folds = train_walkforward(closes, highs, lows, volumes)
    if features is None or len(features) == 0:
        return {'error': 'Not enough data for training'}
    results = {
        'version': '1.0.0',
        'type': 'xgboost',
        'trainedAt': datetime.now(timezone.utc).isoformat(),
        'featureCount': features.shape[1],
        'sampleCount': len(features),
        'folds': len(folds),
    }
    model = None
    best_auc = 0
    best_fold_metrics = {}
    all_probs = []
    all_labels = []
    if HAS_XGB:
        xgb_params = {
            'objective': 'multi:softprob',
            'num_class': 3,
            'max_depth': 6,
            'learning_rate': 0.05,
            'n_estimators': 200,
            'subsample': 0.8,
            'colsample_bytree': 0.8,
            'reg_alpha': 0.1,
            'reg_lambda': 1.0,
            'eval_metric': 'mlogloss',
            'random_state': 42,
            'n_jobs': -1,
        }
        fold_metrics = []
        for train_idx, test_idx in folds:
            X_train, X_test = features[train_idx], features[test_idx]
            y_train, y_test = labels[train_idx], labels[test_idx]
            dtrain = xgb.DMatrix(X_train, label=y_train)
            dtest = xgb.DMatrix(X_test, label=y_test)
            evals_result = {}
            model = xgb.train(
                xgb_params,
                dtrain,
                num_boost_round=200,
                evals=[(dtrain, 'train'), (dtest, 'test')],
                evals_result=evals_result,
                verbose_eval=False,
            )
            proba = model.predict(dtest)
            pred_labels = np.argmax(proba, axis=1)
            accuracy = np.mean(pred_labels == y_test)
            loss = log_loss(y_test, proba, labels=[0, 1, 2])
            brier = brier_score_loss(y_test, proba[:, 0], pos_label=0)
            fold_metrics.append({'accuracy': accuracy, 'logloss': loss, 'brier': brier})
            all_probs.extend(proba.tolist())
            all_labels.extend(y_test.tolist())
        results['foldMetrics'] = fold_metrics
        results['avgAccuracy'] = np.mean([m['accuracy'] for m in fold_metrics])
        results['avgLogLoss'] = np.mean([m['logloss'] for m in fold_metrics])
        results['avgBrier'] = np.mean([m['brier'] for m in fold_metrics])
        best_model = model
        best_auc = results['avgAccuracy']
        model_type = 'xgboost'
    elif HAS_LGB:
        model_type = 'lightgbm'
        results['error'] = 'LightGBM training placeholder'
    else:
        model_type = 'ruleBased'
        results['error'] = 'No ML library available'
    results['modelType'] = model_type
    results['featureNames'] = [
        'ema_alignment', 'ema_long_alignment', 'rsi', 'macd_histogram',
        'atr_ratio', 'bollinger_position', 'volume_ratio', 'vroc',
        'price_direction', 'price_direction_neg', 'atr_volatility',
        'upper_shadow_ratio', 'lower_shadow_ratio',
    ]
    results['treeCount'] = 200 if model_type == 'xgboost' else 0
    results['baseScore'] = 0.33
    results['metrics'] = {
        'accuracy': results.get('avgAccuracy', 0),
        'logLoss': results.get('avgLogLoss', 1.0),
        'brierScore': results.get('avgBrier', 0.25),
    }
    results['expectancy'] = 0.0
    results['sharpeRatio'] = 0.0
    model_name = os.path.join(output_dir, 'ml_model.json')
    export_model_json(results, best_model if model_type == 'xgboost' else None, model_name, features, labels)
    return results


def export_model_json(results, xgb_model, output_path, features, labels):
    export_data = {
        'version': results.get('version', '1.0.0'),
        'type': results.get('modelType', 'ruleBased'),
        'trainedAt': results.get('trainedAt', ''),
        'metrics': results.get('metrics', {}),
        'featureNames': results.get('featureNames', []),
        'treeCount': results.get('treeCount', 0),
        'baseScore': results.get('baseScore', 0.5),
        'foldMetrics': results.get('foldMetrics', []),
    }
    if xgb_model is not None:
        try:
            tree_dump = xgb_model.get_dump(dump_format='json')
            export_data['trees'] = [json.loads(t) for t in tree_dump]
        except Exception:
            export_data['trees'] = []
    else:
        export_data['trees'] = []
    os.makedirs(os.path.dirname(output_path) or '.', exist_ok=True)
    with open(output_path, 'w') as f:
        json.dump(export_data, f, indent=2)


def generate_synthetic_data(n=1000):
    closes = [100.0]
    highs = [101.0]
    lows = [99.0]
    volumes = [1000.0]
    random.seed(42)
    np.random.seed(42)
    for i in range(1, n):
        ret = random.gauss(0.0005, 0.02)
        prev_close = closes[-1]
        close = prev_close * (1 + ret)
        high = close * (1 + abs(random.gauss(0, 0.01)))
        low = close * (1 - abs(random.gauss(0, 0.01)))
        volume = max(100, random.gauss(1000, 300))
        closes.append(close)
        highs.append(high)
        lows.append(low)
        volumes.append(volume)
    return closes, highs, lows, volumes


def main():
    parser = argparse.ArgumentParser(description='Train ML model for crypto futures prediction')
    parser.add_argument('--data', type=str, default=None, help='Path to kline JSON data')
    parser.add_argument('--output', type=str, default='assets/ml_model.json', help='Output model path')
    parser.add_argument('--synth', action='store_true', help='Use synthetic data')
    parser.add_argument('--splits', type=int, default=5, help='Number of walk-forward splits')
    parser.add_argument('--forward', type=int, default=6, help='Forward periods for labeling')
    args = parser.parse_args()

    if args.synth or args.data is None:
        closes, highs, lows, volumes = generate_synthetic_data(1000)
        print('Using synthetic data (1000 candles)')
    else:
        closes, highs, lows, volumes = load_klines(args.data)
        print(f'Loaded {len(closes)} candles from {args.data}')

    print(f'Training with {len(closes)} samples, {args.splits} folds, {args.forward} forward periods...')
    results = train_model(closes, highs, lows, volumes, os.path.dirname(args.output))

    print(f'\nTraining results:')
    print(f'  Model type: {results.get("modelType", "unknown")}')
    print(f'  Accuracy: {results.get("avgAccuracy", 0):.4f}')
    print(f'  Log Loss: {results.get("avgLogLoss", 0):.4f}')
    print(f'  Brier Score: {results.get("avgBrier", 0):.4f}')
    print(f'  Model exported to: {args.output}')


if __name__ == '__main__':
    main()