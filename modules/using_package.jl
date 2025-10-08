# """
#     using_package.jl

# This script imports a collection of essential Julia packages commonly used for data manipulation, statistical analysis, file I/O, and utility functions in supply chain analytics workflows.

# # Imported Packages
# - `DataFrames`, `DataFramesMeta`: For data manipulation and transformation.
# - `SparseArrays`: For efficient storage and computation with sparse matrices.
# - `Dates`: For date and time handling.
# - `CSV`, `XLSX`: For reading and writing CSV and Excel files.
# - `ProgressMeter`: For displaying progress bars during long computations.
# - `Statistics`, `StatsBase`: For statistical functions and utilities.
# - `LinearAlgebra`: For linear algebra operations.
# - `Random`: For random number generation.
# - `Missings`: For handling missing data.
# - `JLD2`: For saving and loading Julia data files.
# - `Combinatorics`: For combinatorial functions.
# - `Unicode`: For Unicode string handling.
# - `Printf`: For formatted output.
# - `StringEncodings`: For string encoding conversions.

# # Package Version Notes
# The script includes comments specifying recommended versions for key packages to ensure compatibility and reproducibility.
# """
using DataFrames, DataFramesMeta, SparseArrays, Dates, CSV, XLSX, ProgressMeter, Statistics, LinearAlgebra, Random, Missings, StatsBase, JLD2, Combinatorics, Unicode, Printf, StringEncodings
# add DataFrames @0.22.1
# add DataFramesMeta @0.6.0
# add CSV @0.8.2
# add Missings @0.4.4
# add StatsBase @0.33.2
# add JLD2 @0.4.3
# add Combinatorics @1.0.2
