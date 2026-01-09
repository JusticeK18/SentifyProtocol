# SentifyProtocol

## Decentralized Sentiment-Driven Price Discovery and Prediction Market

---

### **Overview**

I have designed the **SentifyProtocol**, a high-fidelity decentralized prediction market framework engineered specifically for the Stacks blockchain ecosystem. This protocol serves as a bridge between social sentiment and financial price action, allowing participants to monetize their market intuition and analytical precision.

Unlike traditional "Yes/No" binary prediction markets, I have built SentifyProtocol to handle multi-dimensional data points. It doesn't just ask *if* a price will go up; it asks *how much* and *why*, rewarding users based on a sophisticated hybrid accuracy engine that weighs directional sentiment against numerical price proximity. By requiring a minimum stake in STX, I have ensured the protocol maintains high Sybil resistance and high-integrity data aggregation.

---

### **Protocol Lifecycle**

I have structured the lifecycle of every prediction round to ensure fairness, transparency, and sufficient time for market movement. The protocol moves through distinct phases:

1. **Initiation Phase**: A round is created for a specific asset (e.g., "BTC"). Parameters like the initial price and the "Target Block" (the future block height for evaluation) are locked into the contract state.
2. **Staking & Submission Phase**: Users submit their "Sentiment" (Bullish, Neutral, or Bearish) along with a specific price target. Their STX stake is transferred to the contract's escrow.
3. **Observation Phase**: Once the `end-block` is reached, the round closes for new entries. The protocol then waits for the blockchain to reach the `target-block`.
4. **Resolution Phase**: An authorized entity (the creator or owner) provides the final price at the target height. The contract validates this against the block height.
5. **Claim & Reputation Phase**: Users trigger the reward calculation. I have programmed the contract to automatically update the user's reputation score and distribute rewards based on their performance.

---

### **In-Depth Technical Architecture**

I have architected the contract using a strict separation of concerns, utilizing private functions for sensitive logic and public functions for the user interface.

#### **I. Private Functions: The Core Logic Engine**

These internal functions are the "brain" of the protocol, handling the heavy lifting of mathematical evaluations and ensuring that reward distributions are mathematically sound.

* **`calculate-accuracy-score`**: This function is a sophisticated evaluation tool. I designed it to calculate a score from  to .
* **Directional Check**: It first determines if the user's sentiment aligns with reality (e.g., was it "Bullish" while the price actually rose?).
* **Proximity Calculation**: It calculates the percentage difference between the `predicted-price` and `actual-price`.
* **The Hybrid Result**: If the direction is correct, the score is calculated as:



If the direction is wrong, the score is capped at:



This ensures that even a perfect price guess is penalized if the user fundamentally misunderstood the market direction.


* **`calculate-reward`**: This handles the payout logic. I implemented a two-tier reward system:
1. **Stake Multiplier**: A reward based on the individual's original stake adjusted by their accuracy.
2. **Pool Bonus**: A portion of the total round's stake pool, distributed to accurate predictors to incentivize participation in high-volume markets.


* **`update-user-reputation`**: This manages the on-chain "Proof of Alpha." I designed this to update four key metrics: total predictions, correct predictions, total earnings, and a weighted reputation score. This turns the protocol into a leaderboard for top market analysts.
* **`is-valid-sentiment`**: A simple but critical validation check that ensures users only input the integers , , or , protecting the contract from unexpected state transitions.

#### **II. Public Functions: The User Interface**

These functions are the primary touchpoints for dApp integration and user interaction.

* **`create-prediction-round`**: I've enabled this to allow anyone to spin up a new market. It initializes the `prediction-rounds` and `sentiment-aggregates` maps. This decentralizes the creation of "Pulse" checks for any asset identifier.
* **`submit-prediction`**: This is where the magic happens. I built this to handle the STX staking and the live updating of the "Weighted Sentiment." Every time a user stakes, the protocol recalculates the average sentiment of the crowd, providing a real-time sentiment index.
* **`resolve-prediction-round`**: This function requires the `block-height` to be greater than or equal to the `target-block`. I've added this safety check to ensure no one can settle a round early before the market has had time to move.
* **`claim-prediction-reward`**: I designed this to be a "pull" mechanism. Users must call this to get their STX. It calculates the reward, deducts a  protocol fee (defined in `protocol-fee-percentage`), and updates the user's reputation in a single atomic transaction.

---

### **Data Structure & Storage**

I have optimized the data maps to minimize gas costs while maximizing the data available for front-end developers:

* **`prediction-rounds`**: Stores the "Source of Truth" for every market.
* **`user-predictions`**: Tracks individual stakes and whether a user has already claimed their reward.
* **`sentiment-aggregates`**: Holds the "Crowd Wisdom" data—counting bearish vs. bullish votes and calculating the weighted sentiment.
* **`user-reputation`**: A permanent, global map that follows a principal (user address) across all rounds they participate in.

---

### **Error Handling Reference**

| Constant | Code | Description |
| --- | --- | --- |
| `err-owner-only` | `u100` | Operation restricted to the contract owner. |
| `err-not-found` | `u101` | The requested Asset/Round ID does not exist. |
| `err-insufficient-stake` | `u102` | Stake is below the  STX minimum. |
| `err-prediction-closed` | `u103` | Entry attempted after the `end-block`. |
| `err-already-predicted` | `u104` | Each principal is limited to one prediction per round. |
| `err-invalid-sentiment` | `u105` | Input must be  (Bearish),  (Neutral), or  (Bullish). |
| `err-prediction-active` | `u106` | Cannot resolve a round before the `target-block`. |
| `err-already-resolved` | `u107` | Round has already been settled. |

---

### **Installation and Development**

To interact with this contract locally, I recommend using the **Clarinet** framework.

#### **Prerequisites**

* Clarinet installed on your machine.
* A Stacks-compatible wallet (for deployment).

#### **Execution**

```bash
# Clone the repository
git clone https://github.com/your-username/SentifyProtocol.git

# Check the contract syntax
clarinet check

# Run the test suite
clarinet test

```

---

### **Contribution & Development**

I welcome collaboration to improve the accuracy algorithms or add support for SIP-010 tokens.

1. **Fork** the project.
2. **Clone** your fork.
3. **Test** using Clarinet: `clarinet test`.
4. **Submit** a Pull Request with a detailed description of changes.

---

### **Full MIT License**

```text
The MIT License (MIT)

Copyright (c) 2026 SentifyProtocol Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

---

### **Disclaimer**

I have developed this protocol for educational and market intelligence purposes. Participation in decentralized prediction markets involves financial risk. Users should ensure compliance with their local jurisdictions.
