"""
Fits per-target linear regressions predicting (co2_kg, runoff_intensity,
plastic_intensity, water_l_per_kg) from (category one-hot, log size_kg).

Pure-stdlib Gaussian elimination -- no numpy/sklearn dependency so teammates
without a data-science env can still regenerate the model.

Inputs: ml/env_regression/agribalyse_curated.csv
Outputs:
  - ml/env_regression/model.json           (coefficients + metadata)
  - ios/Clens/Resources/ML/env_regression.json   (bundle copy for iOS)
"""

import csv
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
CSV_PATH = os.path.join(HERE, "agribalyse_curated.csv")
MODEL_JSON = os.path.join(HERE, "model.json")
IOS_BUNDLE = os.path.join(
    HERE, "..", "..", "ios", "Clens", "Resources", "ML", "env_regression.json"
)
IOS_SWIFT = os.path.join(
    HERE, "..", "..", "ios", "Clens", "Services", "Scoring", "EnvRegressionModel.swift"
)

CATEGORIES = [
    "beef", "dairy", "poultry", "seafood", "vegetables", "fruit",
    "legumes", "grains", "packaged snacks", "beverages", "household", "unknown",
]

TARGETS = ["co2_kg", "runoff_intensity", "plastic_intensity", "water_l_per_kg"]


def load_rows(path):
    rows = []
    with open(path, newline="") as fh:
        reader = csv.DictReader(fh)
        for r in reader:
            rows.append({
                "category": r["category"].strip().lower(),
                "size_kg": float(r["size_kg"]),
                "co2_kg": float(r["co2_kg"]),
                "runoff_intensity": float(r["runoff_intensity"]),
                "plastic_intensity": float(r["plastic_intensity"]),
                "water_l_per_kg": float(r["water_l_per_kg"]),
            })
    return rows


def feature_vector(category, size_kg):
    """[bias, one-hot categories..., log_size_kg] — D = 2 + len(CATEGORIES)."""
    vec = [1.0]
    vec.extend(1.0 if c == category else 0.0 for c in CATEGORIES)
    vec.append(math.log(max(size_kg, 1e-3)))
    return vec


def solve_normal_equations(X, y):
    """Solve (XᵀX) β = Xᵀy via Gaussian elimination with partial pivoting.
    Adds a tiny ridge term (λ=1e-6) so the matrix stays invertible when a
    one-hot column has few examples."""
    n = len(X)
    d = len(X[0])
    # Build XᵀX (d×d) and Xᵀy (d×1).
    XtX = [[0.0] * d for _ in range(d)]
    Xty = [0.0] * d
    for row, target in zip(X, y):
        for i in range(d):
            Xty[i] += row[i] * target
            for j in range(d):
                XtX[i][j] += row[i] * row[j]
    ridge = 1e-6
    for i in range(d):
        XtX[i][i] += ridge

    # Gaussian elimination on the augmented matrix.
    A = [XtX[i] + [Xty[i]] for i in range(d)]
    for col in range(d):
        pivot = max(range(col, d), key=lambda r: abs(A[r][col]))
        if abs(A[pivot][col]) < 1e-12:
            raise ValueError(f"singular matrix at col {col}")
        A[col], A[pivot] = A[pivot], A[col]
        pv = A[col][col]
        for r in range(d):
            if r == col:
                continue
            factor = A[r][col] / pv
            if factor == 0.0:
                continue
            for k in range(col, d + 1):
                A[r][k] -= factor * A[col][k]
    return [A[i][d] / A[i][i] for i in range(d)]


def evaluate(X, y, beta):
    """Return R² and mean absolute error."""
    y_mean = sum(y) / len(y)
    ss_tot = sum((yi - y_mean) ** 2 for yi in y)
    ss_res = 0.0
    abs_err = 0.0
    for row, yi in zip(X, y):
        pred = sum(row[k] * beta[k] for k in range(len(beta)))
        ss_res += (yi - pred) ** 2
        abs_err += abs(yi - pred)
    r2 = 1.0 - ss_res / ss_tot if ss_tot > 0 else float("nan")
    return r2, abs_err / len(y)


def main():
    rows = load_rows(CSV_PATH)
    if not rows:
        raise SystemExit(f"No rows loaded from {CSV_PATH}")

    X = [feature_vector(r["category"], r["size_kg"]) for r in rows]

    feature_names = ["bias"] + [f"cat_{c}" for c in CATEGORIES] + ["log_size_kg"]
    per_target = {}
    for tname in TARGETS:
        y = [r[tname] for r in rows]
        beta = solve_normal_equations(X, y)
        r2, mae = evaluate(X, y, beta)
        per_target[tname] = {
            "coefficients": beta,
            "r2": r2,
            "mae": mae,
        }
        print(f"{tname:22s}  R²={r2:6.3f}  MAE={mae:.3f}")

    waters = sorted(r["water_l_per_kg"] for r in rows)
    water_median_log = math.log(waters[len(waters) // 2])

    model = {
        "version": 1,
        "feature_names": feature_names,
        "categories": CATEGORIES,
        "targets": per_target,
        # Used at inference time to recenter the water normalization: a product
        # whose predicted water_l_per_kg matches the dataset median lands at
        # exactly 0.5 on the water intensity scale (pre-stress).
        "water_median_log": water_median_log,
        # Reference size (kg) for the size-scaling term. A scanned product
        # this size gets size_scale = 1.0; smaller/larger products get
        # dampened sqrt-scaled adjustments.
        "reference_size_kg": 0.5,
        "training_rows": len(rows),
    }

    with open(MODEL_JSON, "w") as fh:
        json.dump(model, fh, indent=2)
    print(f"\nwrote {MODEL_JSON}")

    os.makedirs(os.path.dirname(IOS_BUNDLE), exist_ok=True)
    with open(IOS_BUNDLE, "w") as fh:
        json.dump(model, fh, indent=2)
    print(f"wrote {IOS_BUNDLE}")

    write_swift(model)
    print(f"wrote {IOS_SWIFT}")


def fmt_array(values, indent=8):
    pad = " " * indent
    lines = [pad + ", ".join(f"{v:.10g}" for v in values[i:i + 6])
             for i in range(0, len(values), 6)]
    return ",\n".join(lines)


def write_swift(model):
    os.makedirs(os.path.dirname(IOS_SWIFT), exist_ok=True)
    cats = model["categories"]
    cat_cases = "\n".join(f'        case "{c}": return {i}' for i, c in enumerate(cats))
    targets = model["targets"]

    def block(name):
        coefs = targets[name]["coefficients"]
        r2 = targets[name]["r2"]
        mae = targets[name]["mae"]
        return (f"    // {name}  R²={r2:.3f}  MAE={mae:.3f}\n"
                f"    static let {name}Coef: [Double] = [\n"
                f"{fmt_array(coefs)}\n"
                f"    ]")

    swift = f"""import Foundation

// AUTO-GENERATED by ml/env_regression/train.py. Do not edit by hand — rerun
// the trainer to update coefficients after editing agribalyse_curated.csv.
//
// Predicts (co2_kg, runoff_intensity, plastic_intensity, water_l_per_kg) for a
// grocery item from (category one-hot, log size_kg). Trained on a curated
// Agribalyse-derived dataset; see ml/env_regression/agribalyse_curated.csv.
enum EnvRegressionModel {{

    struct Prediction {{
        var co2Kg: Double           // kg CO2-eq per kg product
        var runoffIntensity: Double // 0..1, higher = more fertilizer runoff
        var plasticIntensity: Double// 0..1, higher = more plastic burden
        var waterLPerKg: Double     // liters per kg product
    }}

    static let categories: [String] = [
{chr(10).join(f'        "{c}",' for c in cats)}
    ]

    static func categoryIndex(_ category: FoodCategory) -> Int {{
        switch category.rawValue {{
{cat_cases}
        default: return {cats.index("unknown")}
        }}
    }}

{block("co2_kg")}

{block("runoff_intensity")}

{block("plastic_intensity")}

{block("water_l_per_kg")}

    // Dataset-median of log(water_l_per_kg). Used by OceanScoreEngine to
    // recenter the water normalization so typical products land mid-scale.
    static let waterMedianLog: Double = {model['water_median_log']:.10g}
    // Reference size (kg): scanned products this size get size_scale = 1.
    static let referenceSizeKg: Double = {model['reference_size_kg']}
    static let trainingRows: Int = {model['training_rows']}

    // Build [bias, cat one-hot..., log(size_kg)] feature vector.
    private static func features(for category: FoodCategory, sizeKg: Double) -> [Double] {{
        var vec = [Double](repeating: 0.0, count: 2 + categories.count)
        vec[0] = 1.0
        let idx = categoryIndex(category)
        vec[1 + idx] = 1.0
        vec[vec.count - 1] = log(max(sizeKg, 1e-3))
        return vec
    }}

    private static func dot(_ a: [Double], _ b: [Double]) -> Double {{
        var sum = 0.0
        for i in 0..<a.count {{ sum += a[i] * b[i] }}
        return sum
    }}

    static func predict(category: FoodCategory, sizeKg: Double) -> Prediction {{
        let x = features(for: category, sizeKg: sizeKg)
        return Prediction(
            co2Kg:            max(0.0, dot(x, co2_kgCoef)),
            runoffIntensity:  min(1.0, max(0.0, dot(x, runoff_intensityCoef))),
            plasticIntensity: min(1.0, max(0.0, dot(x, plastic_intensityCoef))),
            waterLPerKg:      max(0.0, dot(x, water_l_per_kgCoef))
        )
    }}
}}
"""
    with open(IOS_SWIFT, "w") as fh:
        fh.write(swift)


if __name__ == "__main__":
    main()
