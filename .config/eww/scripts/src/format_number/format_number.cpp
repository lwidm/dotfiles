// scripts/src/format_number/format_number.cpp

#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

#include "format_number.h"

/**
 * Formats a double precision float with appostrophes as thousand separators.
 *
 * @param num The (double) number to be formatted.
 * @param decimal_places The number of decimal places to display. If negative,
 *        the number is displayed without specific formatting for decimals.
 * @return A string representation of the formatted number with appostrophes.
 */
std::string format_with_apostrophes(double num, int decimal_places) {
  // Format the number with fixed-point notation and set the precision if
  // specified.
  std::ostringstream oss;
  std::string numStr;
  // If no decimal point, start from the end of the string
  if (decimal_places >= 0) {
    oss << std::fixed << std::setprecision(decimal_places) << num;
    numStr = oss.str();
  } else {
    numStr = std::to_string(num);
  }

  if (num >= 10000) {
    std::size_t pos = numStr.find('.');
    if (pos == std::string::npos) {
      pos = numStr.length();
    }
    do {
      pos -= 3;
      numStr.insert(pos, "'");
    } while (pos > 3);
  }

  return numStr;
}
