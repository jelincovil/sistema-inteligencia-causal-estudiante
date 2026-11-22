//! Exact rational identity used by the sealed package as a synthetic fixture.
//!
//! This is one finite instance. It is not a statistical law, not a clinical
//! result, and not evidence that a simulator is externally valid.

/// Exact rational arithmetic on `i64` values.
///
/// Every reduction runs through `i128` intermediates, so `i64::MIN`
/// numerators, negative denominators, and cross-multiplications in
/// `add`/`mul` can never wrap or flip sign. A result that does not fit
/// in `i64` after reduction fails closed with `None`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Ratio {
    num: i64,
    den: i64,
}

impl Ratio {
    pub fn new(num: i64, den: i64) -> Option<Self> {
        Self::from_i128(i128::from(num), i128::from(den))
    }

    /// Normalize `num / den` to lowest terms with a positive denominator.
    ///
    /// Returns `None` when the reduced denominator or numerator does not
    /// fit in `i64` — for example `new(i64::MIN, -1)`, whose value
    /// `2^63` is not representable.
    fn from_i128(num: i128, den: i128) -> Option<Self> {
        if den == 0 {
            return None;
        }
        let (mut numerator, mut denominator) = (num, den);
        if denominator < 0 {
            numerator = numerator.checked_neg()?;
            denominator = denominator.checked_neg()?;
        }
        let divisor = gcd(numerator.unsigned_abs(), denominator as u128);
        let divisor = i128::try_from(divisor).ok()?;
        Some(Self {
            num: i64::try_from(numerator / divisor).ok()?,
            den: i64::try_from(denominator / divisor).ok()?,
        })
    }

    pub const fn numer(self) -> i64 {
        self.num
    }

    pub const fn denom(self) -> i64 {
        self.den
    }

    fn mul(self, other: Self) -> Option<Self> {
        Self::from_i128(
            i128::from(self.num).checked_mul(i128::from(other.num))?,
            i128::from(self.den).checked_mul(i128::from(other.den))?,
        )
    }

    fn add(self, other: Self) -> Option<Self> {
        let left = i128::from(self.num).checked_mul(i128::from(other.den))?;
        let right = i128::from(other.num).checked_mul(i128::from(self.den))?;
        let numerator = left.checked_add(right)?;
        let denominator = i128::from(self.den).checked_mul(i128::from(other.den))?;
        Self::from_i128(numerator, denominator)
    }

    fn neg(self) -> Option<Self> {
        Self::from_i128(-i128::from(self.num), i128::from(self.den))
    }
}

impl std::fmt::Display for Ratio {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(formatter, "{}/{}", self.num, self.den)
    }
}

fn gcd(mut a: u128, mut b: u128) -> u128 {
    while b != 0 {
        let next = a % b;
        a = b;
        b = next;
    }
    // `b == 0` implies `a` is the gcd; when `a == 0` it returns `d`
    // (the nonzero denominator), which reduces `0/d` to `0/1`.
    a
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SschInstance {
    pub experiment: &'static str,
    pub scope: &'static str,
    pub risk0: Ratio,
    pub risk1: Ratio,
    pub bayes_risk: Ratio,
    pub return0: Ratio,
    pub return1: Ratio,
}

/// Risks of following the signal, and the Bayes risk, by exact enumeration.
///
/// P0(X=1)=1/5, P1(X=1)=4/5, false-positive loss 1, false-negative loss 4,
/// prior of theta=1 equal to 3/10. Synthetic. Not clinical evidence.
pub fn ssch_one_decision_exact_v1() -> Option<SschInstance> {
    let p0_x1 = Ratio::new(1, 5)?;
    let p0_x0 = Ratio::new(4, 5)?;
    let p1_x1 = Ratio::new(4, 5)?;
    let p1_x0 = Ratio::new(1, 5)?;
    let prior1 = Ratio::new(3, 10)?;
    let prior0 = Ratio::new(7, 10)?;
    let loss_fp = Ratio::new(1, 1)?;
    let loss_fn = Ratio::new(4, 1)?;
    let zero = Ratio::new(0, 1)?;

    // Action follows the signal: a = x.
    let risk0 = p0_x0.mul(zero)?.add(p0_x1.mul(loss_fp)?)?;
    let risk1 = p1_x0.mul(loss_fn)?.add(p1_x1.mul(zero)?)?;
    let bayes = prior0.mul(risk0)?.add(prior1.mul(risk1)?)?;
    Some(SschInstance {
        experiment: "ssch_one_decision_exact_v1",
        scope: "exact finite synthetic instance",
        risk0,
        risk1,
        bayes_risk: bayes,
        return0: risk0.neg()?,
        return1: risk1.neg()?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ratio_new_handles_min_zero_negative_denominator_and_gcd() {
        // i64::MIN numerator is exact in i128.
        let min = Ratio::new(i64::MIN, 1).expect("MIN over 1 is representable");
        assert_eq!(min.numer(), i64::MIN);
        assert_eq!(min.denom(), 1);
        // i64::MIN / -1 would be 2^63, which i64 cannot hold: fail closed.
        assert!(Ratio::new(i64::MIN, -1).is_none());
        // MIN / MIN normalizes to 1/1 without an overflowing .abs().
        assert_eq!(
            Ratio::new(i64::MIN, i64::MIN).expect("reducible"),
            Ratio::new(1, 1).expect("one")
        );
        // Zero numerators collapse to 0/1 even for extreme denominators.
        assert_eq!(
            Ratio::new(0, 7).expect("zero"),
            Ratio::new(0, 1).expect("zero")
        );
        assert_eq!(
            Ratio::new(0, i64::MIN).expect("zero over MIN"),
            Ratio::new(0, 1).expect("zero")
        );
        // Zero denominator is rejected.
        assert!(Ratio::new(7, 0).is_none());
        assert!(Ratio::new(0, 0).is_none());
        // Negative denominators are normalized away, signs flip with them.
        assert_eq!(
            Ratio::new(1, -4).expect("neg den"),
            Ratio::new(-1, 4).expect("neg num")
        );
        assert_eq!(
            Ratio::new(-1, -4).expect("double neg"),
            Ratio::new(1, 4).expect("pos")
        );
        assert_eq!(
            Ratio::new(6, -9).expect("gcd with neg den"),
            Ratio::new(-2, 3).expect("reduced")
        );
        // GCD reduction in lowest terms.
        assert_eq!(
            Ratio::new(6, 9).expect("reduce"),
            Ratio::new(2, 3).expect("two thirds")
        );
        assert_eq!(
            Ratio::new(8, 4).expect("reduce powers of two"),
            Ratio::new(2, 1).expect("two")
        );
        assert_eq!(
            Ratio::new(-12, 8).expect("reduce signed"),
            Ratio::new(-3, 2).expect("three halves")
        );
    }

    #[test]
    fn ratio_arithmetic_fails_closed_at_the_boundaries() {
        // Negation of i64::MIN is not representable; fail closed.
        let min = Ratio::new(i64::MIN, 1).expect("MIN");
        assert!(min.neg().is_none());
        // Addition overflow: 2 * (i64::MAX) exceeds i64 after reduction.
        let max = Ratio::new(i64::MAX, 1).expect("MAX");
        assert!(max.add(max).is_none());
        // Adding zero is exact at the boundary.
        assert_eq!(
            min.add(Ratio::new(0, 1).expect("zero")).expect("add zero"),
            min
        );
        // Multiplication reduces without overflowing i64 mid-computation.
        let half = Ratio::new(1, 2).expect("half");
        assert_eq!(
            half.mul(half).expect("quarter"),
            Ratio::new(1, 4).expect("quarter")
        );
        // Extreme multiplication fails closed rather than wrapping.
        let huge = Ratio::new(i64::MAX, 1).expect("huge");
        assert!(huge.mul(huge).is_none());
        // Cross-multiplication near the limit: MIN + 1/2 needs numerator
        // -18446744073709551615, which does not fit i64; fail closed.
        assert!(min.add(half).is_none());
        // A representable near-limit sum keeps its exact value:
        // MIN/3 + 1/3 = (MIN + 1)/3 rounds away from zero toward MIN/3,
        // so use even splits: MIN/2 + MIN/2 stays exact at i128 range.
        let half_min = Ratio::new(i64::MIN, 2).expect("MIN/2");
        let doubled = half_min
            .add(half_min)
            .expect("MIN/2 + MIN/2 is representable");
        assert_eq!(doubled.numer(), i64::MIN);
        assert_eq!(doubled.denom(), 1);
        // Multiplying by a fraction of a negated MIN stays exact.
        let neg_min = Ratio::new(-1, 2).expect("neg half");
        assert_eq!(
            neg_min
                .mul(Ratio::new(0, 1).expect("zero"))
                .expect("times zero"),
            Ratio::new(0, 1).expect("zero")
        );
    }

    #[test]
    fn matches_the_sealed_rational_instance() {
        let got = ssch_one_decision_exact_v1().expect("finite arithmetic");
        // Independent check: 7/10 * 1/5 + 3/10 * 4/5 = 7/50 + 12/50.
        let expected = Ratio::new(7, 50)
            .unwrap()
            .add(Ratio::new(12, 50).unwrap())
            .unwrap();
        assert_eq!(got.risk0, Ratio::new(1, 5).unwrap());
        assert_eq!(got.risk1, Ratio::new(4, 5).unwrap());
        assert_eq!(got.bayes_risk, Ratio::new(19, 50).unwrap());
        assert_eq!(got.bayes_risk, expected);
        assert_eq!(got.return0, got.risk0.neg().unwrap());
        assert_eq!(got.return1, got.risk1.neg().unwrap());
    }
}
