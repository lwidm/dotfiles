// scripts/src/format_number/format_number_main.cpp
#include <iostream>
#include <string>

#include "formatNumberConfig.h"
#include "format_number.h"

/**
 * Main function to format a number passed from the command line.
 *
 * Usage: ./format_number <number> [<decimal_places>]
 *
 * @param argc Number of command-line arguments passed.
 * @param argv Command-line arguments (argv[1] should be the number, argv[2]
 * optional decimal places).
 * @return 0 on success, 1 on failure.
 */
int main(int argc, char *argv[]) {
  try {
    // Ensure that between 1 and 2 arguments are passed.
    if (!(argc >= 2 && argc < 4)) {
      std::string arguments_string = "arguments";
      if (argc == 2) {
        arguments_string = "argument";
      }
      std::cerr << "format_number: Usage: " << argv[0]
                << " <number> [<decimal_places>] (" << argc - 1 << " "
                << arguments_string << " passed)" << '\n';
      std::cout << "format_number: Version: " << formatNumber_VERSION_MAJOR
                << "." << formatNumber_VERSION_MINOR << std::endl;
      return 1;
    }

    // Parse decimal places if the third argument is provided
    int decimal_places = -1;
    if (argc == 3) {
      decimal_places = std::stoi(argv[2]);
    }

    double num = std::stod(argv[1]);
    std::string fmt_numStr = format_with_apostrophes(num, decimal_places);
    std::cout << fmt_numStr;
    return 0;

  } catch (const std::exception &e) {
    std::cerr << "format_number: Error: " << e.what() << std::endl;
    return 1;
  }
}
