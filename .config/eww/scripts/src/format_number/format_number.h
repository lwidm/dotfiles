// scripts/src/format_number/format_number.h

#include <string>

/**
 * Formats a double precision float with appostrophes as thousand separators.
 *
 * @param num The (double) number to be formatted.
 * @param decimal_places The number of decimal places to display. If negative,
 *        the number is displayed without specific formatting for decimals.
 * @return A string representation of the formatted number with appostrophes.
 */
std::string format_with_apostrophes(double num, int decimal_places);
