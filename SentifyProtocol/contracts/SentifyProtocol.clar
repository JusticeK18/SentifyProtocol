;; Sentiment-Based Price Prediction Protocol

;; This contract implements a decentralized prediction market where users can stake tokens
;; on their sentiment-based price predictions for various assets. Predictions are evaluated
;; against actual price movements, and accurate predictors earn rewards from a shared pool.
;; The protocol aggregates sentiment data to provide market intelligence while incentivizing
;; honest and accurate predictions through a stake-based reward mechanism.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-stake (err u102))
(define-constant err-prediction-closed (err u103))
(define-constant err-already-predicted (err u104))
(define-constant err-invalid-sentiment (err u105))
(define-constant err-prediction-active (err u106))
(define-constant err-already-resolved (err u107))
(define-constant err-insufficient-balance (err u108))
(define-constant err-invalid-timeframe (err u109))

;; Minimum stake required to submit a prediction (in microSTX)
(define-constant min-stake-amount u1000000)

;; Sentiment values: 1 = bearish, 2 = neutral, 3 = bullish
(define-constant sentiment-bearish u1)
(define-constant sentiment-neutral u2)
(define-constant sentiment-bullish u3)

;; data maps and vars

;; Tracks prediction rounds for different assets
(define-map prediction-rounds
    { asset-id: (string-ascii 20), round-id: uint }
    {
        start-block: uint,
        end-block: uint,
        target-block: uint,
        initial-price: uint,
        final-price: uint,
        total-stake: uint,
        is-resolved: bool,
        created-by: principal
    }
)

;; Stores individual user predictions
(define-map user-predictions
    { asset-id: (string-ascii 20), round-id: uint, predictor: principal }
    {
        sentiment: uint,
        predicted-price: uint,
        stake-amount: uint,
        timestamp: uint,
        is-rewarded: bool
    }
)

;; Aggregated sentiment scores per round
(define-map sentiment-aggregates
    { asset-id: (string-ascii 20), round-id: uint }
    {
        bearish-count: uint,
        neutral-count: uint,
        bullish-count: uint,
        total-predictions: uint,
        weighted-sentiment: uint
    }
)

;; User reputation scores based on prediction accuracy
(define-map user-reputation
    { user: principal }
    {
        total-predictions: uint,
        correct-predictions: uint,
        total-earnings: uint,
        reputation-score: uint
    }
)

;; Global contract statistics
(define-data-var total-rounds uint u0)
(define-data-var total-volume uint u0)
(define-data-var protocol-fee-percentage uint u5) ;; 5% protocol fee

;; private functions

;; Calculate the accuracy score of a prediction
;; Returns a score from 0-100 based on prediction accuracy
(define-private (calculate-accuracy-score 
    (predicted-price uint) 
    (actual-price uint) 
    (sentiment uint)
    (initial-price uint))
    (let
        (
            (price-change (if (>= actual-price initial-price)
                (- actual-price initial-price)
                (- initial-price actual-price)))
            (price-change-percentage (/ (* price-change u100) initial-price))
            (direction-correct (or
                (and (is-eq sentiment sentiment-bullish) (>= actual-price initial-price))
                (and (is-eq sentiment sentiment-bearish) (< actual-price initial-price))
                (and (is-eq sentiment sentiment-neutral) 
                     (<= price-change-percentage u5)))) ;; Neutral if within 5%
            (price-accuracy (if (> actual-price u0)
                (- u100 (/ (* (if (>= predicted-price actual-price)
                    (- predicted-price actual-price)
                    (- actual-price predicted-price)) u100) actual-price))
                u0))
        )
        (if direction-correct
            (/ (+ price-accuracy u100) u2) ;; Average of direction bonus and price accuracy
            (/ price-accuracy u2)) ;; Half points for wrong direction
    )
)

;; Calculate reward amount based on accuracy and stake
(define-private (calculate-reward 
    (accuracy-score uint) 
    (stake-amount uint) 
    (total-pool uint))
    (let
        (
            (base-reward (/ (* stake-amount accuracy-score) u100))
            (pool-bonus (/ (* total-pool accuracy-score) u10000))
        )
        (+ base-reward pool-bonus)
    )
)

;; Update user reputation based on prediction outcome
(define-private (update-user-reputation 
    (user-address principal) 
    (prediction-correct bool) 
    (earnings uint))
    (let
        (
            (current-rep (default-to 
                { total-predictions: u0, correct-predictions: u0, total-earnings: u0, reputation-score: u50 }
                (map-get? user-reputation { user: user-address })))
            (updated-total (+ (get total-predictions current-rep) u1))
            (updated-correct (if prediction-correct 
                (+ (get correct-predictions current-rep) u1)
                (get correct-predictions current-rep)))
            (updated-earnings (+ (get total-earnings current-rep) earnings))
            (new-reputation-score (if (> updated-total u0)
                (/ (* updated-correct u100) updated-total)
                u50))
        )
        (map-set user-reputation
            { user: user-address }
            {
                total-predictions: updated-total,
                correct-predictions: updated-correct,
                total-earnings: updated-earnings,
                reputation-score: new-reputation-score
            }
        )
    )
)

;; Validate sentiment value
(define-private (is-valid-sentiment (sentiment uint))
    (or (is-eq sentiment sentiment-bearish)
        (or (is-eq sentiment sentiment-neutral)
            (is-eq sentiment sentiment-bullish)))
)

;; public functions

;; Create a new prediction round for an asset
;; @param asset-id: Identifier for the asset (e.g., "BTC", "STX")
;; @param duration-blocks: Number of blocks the prediction round will be active
;; @param evaluation-blocks: Blocks to wait after round ends before evaluating
;; @param initial-price: Starting price of the asset (in micro units)
(define-public (create-prediction-round 
    (asset-id (string-ascii 20))
    (duration-blocks uint)
    (evaluation-blocks uint)
    (initial-price uint))
    (let
        (
            (round-id (+ (var-get total-rounds) u1))
            (current-height block-height)
            (prediction-end (+ current-height duration-blocks))
            (target-height (+ prediction-end evaluation-blocks))
        )
        ;; Validate inputs
        (asserts! (> duration-blocks u0) err-invalid-timeframe)
        (asserts! (> evaluation-blocks u0) err-invalid-timeframe)
        (asserts! (> initial-price u0) err-invalid-timeframe)
        
        ;; Create the prediction round
        (map-set prediction-rounds
            { asset-id: asset-id, round-id: round-id }
            {
                start-block: current-height,
                end-block: prediction-end,
                target-block: target-height,
                initial-price: initial-price,
                final-price: u0,
                total-stake: u0,
                is-resolved: false,
                created-by: tx-sender
            }
        )
        
        ;; Initialize sentiment aggregates
        (map-set sentiment-aggregates
            { asset-id: asset-id, round-id: round-id }
            {
                bearish-count: u0,
                neutral-count: u0,
                bullish-count: u0,
                total-predictions: u0,
                weighted-sentiment: u0
            }
        )
        
        ;; Update global counter
        (var-set total-rounds round-id)
        (ok round-id)
    )
)

;; Submit a sentiment-based price prediction with stake
;; @param asset-id: The asset being predicted
;; @param round-id: The prediction round identifier
;; @param sentiment: User's sentiment (1=bearish, 2=neutral, 3=bullish)
;; @param predicted-price: User's predicted price at target block
;; @param stake-amount: Amount of tokens to stake on this prediction
(define-public (submit-prediction
    (asset-id (string-ascii 20))
    (round-id uint)
    (sentiment-value uint)
    (predicted-price uint)
    (stake-amount uint))
    (let
        (
            (prediction-round (unwrap! (map-get? prediction-rounds 
                { asset-id: asset-id, round-id: round-id }) err-not-found))
            (current-aggregates (unwrap! (map-get? sentiment-aggregates
                { asset-id: asset-id, round-id: round-id }) err-not-found))
            (existing-prediction (map-get? user-predictions
                { asset-id: asset-id, round-id: round-id, predictor: tx-sender }))
        )
        ;; Validate prediction submission
        (asserts! (is-valid-sentiment sentiment-value) err-invalid-sentiment)
        (asserts! (>= stake-amount min-stake-amount) err-insufficient-stake)
        (asserts! (<= block-height (get end-block prediction-round)) err-prediction-closed)
        (asserts! (is-none existing-prediction) err-already-predicted)
        (asserts! (not (get is-resolved prediction-round)) err-already-resolved)
        
        ;; Store user prediction
        (map-set user-predictions
            { asset-id: asset-id, round-id: round-id, predictor: tx-sender }
            {
                sentiment: sentiment-value,
                predicted-price: predicted-price,
                stake-amount: stake-amount,
                timestamp: block-height,
                is-rewarded: false
            }
        )
        
        ;; Update sentiment aggregates
        (map-set sentiment-aggregates
            { asset-id: asset-id, round-id: round-id }
            {
                bearish-count: (if (is-eq sentiment-value sentiment-bearish)
                    (+ (get bearish-count current-aggregates) u1)
                    (get bearish-count current-aggregates)),
                neutral-count: (if (is-eq sentiment-value sentiment-neutral)
                    (+ (get neutral-count current-aggregates) u1)
                    (get neutral-count current-aggregates)),
                bullish-count: (if (is-eq sentiment-value sentiment-bullish)
                    (+ (get bullish-count current-aggregates) u1)
                    (get bullish-count current-aggregates)),
                total-predictions: (+ (get total-predictions current-aggregates) u1),
                weighted-sentiment: (/ (+ (* (get weighted-sentiment current-aggregates) 
                    (get total-predictions current-aggregates)) sentiment-value)
                    (+ (get total-predictions current-aggregates) u1))
            }
        )
        
        ;; Update round total stake
        (map-set prediction-rounds
            { asset-id: asset-id, round-id: round-id }
            (merge prediction-round { total-stake: (+ (get total-stake prediction-round) stake-amount) })
        )
        
        ;; Update global volume
        (var-set total-volume (+ (var-get total-volume) stake-amount))
        
        (ok true)
    )
)

;; Resolve a prediction round by setting the final price and distributing rewards
;; @param asset-id: The asset identifier
;; @param round-id: The round to resolve
;; @param final-price: The actual price at the target block
(define-public (resolve-prediction-round
    (asset-id (string-ascii 20))
    (round-id uint)
    (final-price uint))
    (let
        (
            (prediction-round (unwrap! (map-get? prediction-rounds 
                { asset-id: asset-id, round-id: round-id }) err-not-found))
        )
        ;; Only contract owner or round creator can resolve
        (asserts! (or (is-eq tx-sender contract-owner) 
                     (is-eq tx-sender (get created-by prediction-round))) err-owner-only)
        
        ;; Validate resolution conditions
        (asserts! (>= block-height (get target-block prediction-round)) err-prediction-active)
        (asserts! (not (get is-resolved prediction-round)) err-already-resolved)
        (asserts! (> final-price u0) err-invalid-timeframe)
        
        ;; Update round with final price and mark as resolved
        (map-set prediction-rounds
            { asset-id: asset-id, round-id: round-id }
            (merge prediction-round { 
                final-price: final-price,
                is-resolved: true 
            })
        )
        
        (ok true)
    )
)

;; Claim rewards for a successful prediction after round resolution
;; This function calculates the user's reward based on their prediction accuracy,
;; updates their reputation score, and transfers the earned tokens to their account.
;; The reward calculation considers both directional accuracy and price precision.
;; @param asset-id: The asset identifier for the prediction round
;; @param round-id: The round identifier to claim rewards from
(define-public (claim-prediction-reward
    (asset-id (string-ascii 20))
    (round-id uint))
    (let
        (
            (prediction-round (unwrap! (map-get? prediction-rounds 
                { asset-id: asset-id, round-id: round-id }) err-not-found))
            (user-pred (unwrap! (map-get? user-predictions
                { asset-id: asset-id, round-id: round-id, predictor: tx-sender }) err-not-found))
            (initial-price-value (get initial-price prediction-round))
            (final-price-value (get final-price prediction-round))
            (predicted-price-value (get predicted-price user-pred))
            (sentiment-value (get sentiment user-pred))
            (stake-value (get stake-amount user-pred))
            (total-stake-value (get total-stake prediction-round))
        )
        ;; Validate claim conditions
        (asserts! (get is-resolved prediction-round) err-prediction-active)
        (asserts! (not (get is-rewarded user-pred)) err-already-predicted)
        (asserts! (> final-price-value u0) err-not-found)
        
        ;; Calculate accuracy score (0-100)
        (let
            (
                (accuracy (calculate-accuracy-score 
                    predicted-price-value 
                    final-price-value 
                    sentiment-value
                    initial-price-value))
                (reward-amount (calculate-reward accuracy stake-value total-stake-value))
                (protocol-fee (/ (* reward-amount (var-get protocol-fee-percentage)) u100))
                (net-reward (- reward-amount protocol-fee))
                (is-correct (>= accuracy u50))
            )
            
            ;; Mark prediction as rewarded
            (map-set user-predictions
                { asset-id: asset-id, round-id: round-id, predictor: tx-sender }
                (merge user-pred { is-rewarded: true })
            )
            
            ;; Update user reputation
            (update-user-reputation tx-sender is-correct net-reward)
            
            ;; Return reward info
            (ok {
                accuracy-score: accuracy,
                reward-amount: net-reward,
                protocol-fee: protocol-fee,
                is-correct: is-correct
            })
        )
    )
)



