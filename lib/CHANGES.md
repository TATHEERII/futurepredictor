# Changes made

## 1. Fixed the compile-blocking bug
`Prediction` declared ~40 `required` fields (wma20/50, hma20/50, aroon*, donchian*,
stochRsi*, roc, ao, ultOsc, mfi, adi, cmf, forceIndex, eom, cmo, rvi*, kvo*, coppock,
vwma20, bullPower, bearPower, massIndex, and 7 candlestick booleans) that
`PredictionService` never computed or passed. `lib/services/prediction_service.dart`
now actually calculates every one of them (standard WMA, Hull MA, Aroon, Donchian,
StochRSI, ROC, Awesome Oscillator, Ultimate Oscillator, MFI, ADI, CMF, Force Index,
Ease of Movement, CMO, RVI, KVO, Coppock Curve, VWMA, Elder Ray, Mass Index, and
doji/hammer/shooting-star/engulfing/three-soldiers/three-crows pattern checks).

## 2. Backtesting (`lib/services/backtest_service.dart`, `lib/models/backtest_result.dart`)
Walk-forward replay of `PredictionService` against historical candles, using only
data available at each simulated point in time (no lookahead). For each non-HOLD
signal it checks whether price hit the ATR-based stop-loss or take-profit first,
and reports win rate, average/total return, max drawdown, a return/volatility
ratio, and — most importantly — **buy-and-hold return over the same window**, so
you can see whether the strategy actually has an edge. Triggered from a new "Run
Backtest" button in `bot_controls_widget.dart` and displayed in
`widgets/backtest_results_widget.dart`.

## 3. Live signal tracking (`lib/services/signal_tracker_service.dart`)
Every non-HOLD prediction is persisted (via `shared_preferences`) with its entry
price, stop, and target. On each refresh, past signals whose holding window has
elapsed are resolved against real price action, and a rolling win rate is computed
and shown on the signal card ("Live tracked accuracy (n=…)"). This is real
performance tracking, separate from the backtest, and is what closes the loop that
was completely missing before — there was previously no way to know if a signal
was ever right.

## 4. Regime detection
`prediction_service.dart` now classifies the market as `trending` or `ranging`
using the already-computed ADX, and re-weights the vote: trend-following
indicators (SMA/EMA cross, MACD, ADX/DI, Parabolic SAR, Ichimoku, Aroon) count more
in a trending regime; mean-reversion indicators (RSI, Bollinger, Stochastic, CCI,
Williams %R, Keltner) count more in a ranging regime. Previously all of these were
blended together with fixed weights regardless of market condition, even though
they often contradict each other.

## 5. Risk levels (stop-loss / take-profit)
Every BUY/SELL prediction now includes an ATR-based `stopLoss`, `takeProfit`, and
`riskRewardRatio` (default ~1.5:1), shown on the signal card. This turns a bare
directional label into something with an actual exit plan, and is also what the
backtester and live tracker use to decide whether a signal "won."

## 6. Multi-timeframe confirmation
`ApiService.fetchHigherTimeframeKlines` pulls 4h candles alongside the 1h series.
`PredictionService.predict` accepts them and checks whether the 4h EMA trend agrees
with the signal direction; if it disagrees, confidence is scaled down (not
discarded) and the card shows a "4h trend agrees/disagrees" chip.

## 7. API resilience (`lib/services/api_service.dart`)
- Retries with exponential backoff + jitter on timeouts, 429s, and 5xx errors.
- Explicit request timeout instead of hanging indefinitely.
- `fetchSymbolInfo` now throws a clear `ApiException` for unknown symbols instead
  of silently returning an empty map (`firstWhere(orElse: () => {})`).

## Required setup
Add to `pubspec.yaml` dependencies (new dependency introduced by signal tracking):

```yaml
dependencies:
  shared_preferences: ^2.2.0
```

Then run `flutter pub get`. I don't have a Dart/Flutter toolchain in this
environment to run `flutter analyze` or `flutter test`, so please run those before
shipping — I've reviewed the code carefully for type/field mismatches, but a real
compiler pass is the only way to be certain.

## What this does *not* fix (still worth doing next)
- Weights (1.0, 1.2, 1.5, etc.) are still hand-picked, not fitted — the backtester
  now at least lets you test changes to them empirically.
- No walk-forward re-optimization; weights are static across the whole backtest.
- Single exchange/symbol source (Binance futures) with no fallback if it's down.
