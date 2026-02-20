# Overall Defect Rate Calculation - Test Cases

## Formula

**Overall Defect Rate = Sum of defect rates (excluding 0%) / Count of iterations with defects**

**Rule**: Iterations with 0% defect rate are excluded from both the sum and the iteration count.

---

## Test Case 1: Single Phase, Single Iteration with Defects

**Scenario**: Project with 1 phase, currently in iteration 1 with 1 defect out of 2 questions

| Phase | Iteration   | Questions | Defects | Defect Rate |
| ----- | ----------- | --------- | ------- | ----------- |
| P1    | 1 (current) | 2         | 1       | 50%         |

**Calculation**:

- Sum of defect rates: 50%
- Count of iterations with defects: 1
- **Overall Defect Rate: 50% / 1 = 50%** ✓

---

## Test Case 2: Single Phase, Multiple Iterations with Mixed Results

**Scenario**: Project with 1 phase, 3 total iterations

| Phase | Iteration   | Questions | Defects | Defect Rate | Include? |
| ----- | ----------- | --------- | ------- | ----------- | -------- |
| P1    | 1 (past)    | 4         | 2       | 50%         | Yes      |
| P1    | 2 (past)    | 4         | 0       | 0%          | No       |
| P1    | 3 (current) | 4         | 3       | 75%         | Yes      |

**Calculation**:

- Sum of defect rates: 50% + 75% = 125% (excluding iteration 2's 0%)
- Count of iterations with defects: 2 (iterations 1 and 3)
- **Overall Defect Rate: 125% / 2 = 62.5%** ✓

---

## Test Case 3: Multiple Phases, All Iterations Have Defects

**Scenario**: Project with 2 phases

| Phase | Iteration   | Questions | Defects | Defect Rate | Include? |
| ----- | ----------- | --------- | ------- | ----------- | -------- |
| P1    | 1 (past)    | 5         | 2       | 40%         | Yes      |
| P1    | 2 (current) | 5         | 1       | 20%         | Yes      |
| P2    | 1 (current) | 3         | 2       | 66.67%      | Yes      |

**Calculation**:

- Sum of defect rates: 40% + 20% + 66.67% = 126.67%
- Count of iterations with defects: 3
- **Overall Defect Rate: 126.67% / 3 = 42.22%** ✓

---

## Test Case 4: Multiple Phases, Some Iterations Have Zero Defects

**Scenario**: Project with 3 phases

| Phase | Iteration   | Questions | Defects | Defect Rate | Include? |
| ----- | ----------- | --------- | ------- | ----------- | -------- |
| P1    | 1 (past)    | 10        | 5       | 50%         | Yes      |
| P1    | 2 (past)    | 10        | 2       | 20%         | Yes      |
| P1    | 3 (current) | 10        | 0       | 0%          | No       |
| P2    | 1 (past)    | 8         | 4       | 50%         | Yes      |
| P2    | 2 (current) | 8         | 0       | 0%          | No       |
| P3    | 1 (current) | 6         | 3       | 50%         | Yes      |

**Calculation**:

- Sum of defect rates: 50% + 20% + 50% + 50% = 170% (excluding P1-iter3 and P2-iter2)
- Count of iterations with defects: 4
- **Overall Defect Rate: 170% / 4 = 42.5%** ✓

---

## Test Case 5: All Iterations Have Zero Defects

**Scenario**: Perfect project with no defects

| Phase | Iteration   | Questions | Defects | Defect Rate | Include? |
| ----- | ----------- | --------- | ------- | ----------- | -------- |
| P1    | 1 (current) | 5         | 0       | 0%          | No       |

**Calculation**:

- Sum of defect rates: 0
- Count of iterations with defects: 0
- **Overall Defect Rate: 0 / 1 = 0%** ✓
  (Note: Divisor is 1 to avoid division by zero)

---

## Test Case 6: User's Current Scenario

**Scenario**: Phase 1 with 1 defect found out of 2 questions (shown in screenshot: 33.33% should be 50%)

| Phase | Iteration   | Questions | Defects | Defect Rate | Include? |
| ----- | ----------- | --------- | ------- | ----------- | -------- |
| P1    | 1 (current) | 2         | 1       | 50%         | Yes      |

**Calculation**:

- Sum of defect rates: 50%
- Count of iterations with defects: 1
- **Overall Defect Rate: 50% / 1 = 50%** ✓

**Previous Incorrect Calculation** (before fix):

- If system was dividing by 3 phases or including zero iterations: 50% / 3 = 16.67% or similar
- Or if counting 3 total iterations incorrectly: 100% / 3 = 33.33% ❌

---

## Test Case 7: Complex Multi-Phase Project

**Scenario**: Large project with many iterations

| Phase | Iteration | Questions | Defects | Defect Rate | Include? |
| ----- | --------- | --------- | ------- | ----------- | -------- |
| P1    | 1         | 20        | 10      | 50%         | Yes      |
| P1    | 2         | 20        | 5       | 25%         | Yes      |
| P1    | 3         | 20        | 2       | 10%         | Yes      |
| P1    | 4         | 20        | 0       | 0%          | No       |
| P2    | 1         | 15        | 12      | 80%         | Yes      |
| P2    | 2         | 15        | 3       | 20%         | Yes      |
| P2    | 3         | 15        | 0       | 0%          | No       |
| P3    | 1         | 10        | 7       | 70%         | Yes      |
| P3    | 2         | 10        | 0       | 0%          | No       |

**Calculation**:

- Sum of defect rates: 50 + 25 + 10 + 80 + 20 + 70 = 255%
- Count of iterations with defects: 6 (excluding 3 iterations with 0%)
- **Overall Defect Rate: 255% / 6 = 42.5%** ✓

---

## Implementation Notes

1. **Zero Detection**: An iteration is considered to have "no defects" when its defect rate is exactly 0% or 0.00
2. **Rounding**: Defect rates are calculated to 2 decimal places (e.g., 42.22%)
3. **Capping**: Individual iteration defect rates are capped at 100% before being included in the calculation
4. **Edge Case**: When no iterations have defects (all 0%), divisor defaults to 1 to avoid division by zero, resulting in 0% overall
5. **Current Iteration**: The current (ongoing) iteration is included in the calculation if it has defects (rate > 0%)
