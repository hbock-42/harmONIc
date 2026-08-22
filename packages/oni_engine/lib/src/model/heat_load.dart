import 'item.dart';

/// The temperature a base is kept at, for want of anywhere better to measure
/// heat *from*.
///
/// Nothing in the game fixes this — a base runs where its cooling leaves it —
/// but a figure in kDTU/s means nothing without a baseline, and every player
/// has one in their head. 25 °C is the middle of what a Duplicant is happy in
/// and what most crops want, so a number measured against it reads the way the
/// question is usually asked: how much cooling does this cost me.
const double comfortableBaseCelsius = 25;

/// How much heat a flow carries, above the heat the same flow would carry at
/// room temperature.
///
/// This is the cooling bill a line brings with it: 10 kg/s of 95 °C water is
/// 2 925 kDTU/s that has to go somewhere before the water is room temperature
/// again. Positive is heat you must remove; negative is a flow cold enough to
/// take heat away, which is worth as much and is easy to forget.
///
/// **What it is not.** It is not a prediction that this heat lands in your
/// base. Where it goes depends on what the pipe is made of, what it runs past
/// and how long it runs — none of which a flow model can see. It is the size
/// of the thing, which is the half worth knowing before you plan around it:
/// a line worth 3 000 kDTU/s is a steam room, and one worth 3 is a rounding
/// error.
///
/// Null when the item has no specific heat, which is every solid here and the
/// non-material ports. A guess at one would put a confident figure on a page
/// that has no business showing one.
double? coolingLoadKdtu(
  Item item,
  double gramsPerSecond,
  double celsius, {
  double fromCelsius = comfortableBaseCelsius,
}) {
  final specificHeat = item.specificHeat;
  if (specificHeat == null) return null;
  return gramsPerSecond * specificHeat * (celsius - fromCelsius) / 1000;
}
