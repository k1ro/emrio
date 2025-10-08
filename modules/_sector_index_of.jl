"""
    _sector_index_of(sector, c::String, s::String)

Return the base-sector index (1..N) within a sector-level MRIO object
for the specified country–sector pair.

### Arguments
- `sector::NamedTuple` : A sector-level MRIO object created by `make_sector_mrio_from_T()`.
- `c::String`          : Country code (e.g., "A", "B").
- `s::String`          : Sector name (e.g., "Primary", "Secondary", "Tertiary").

### Returns
- `Int` : The linear index (1..N) corresponding to the sector located in country `c`
          and industry `s`.

### Behavior
The function scans through `sector.idx_country` and `sector.idx_sector` to find
a matching pair `(country, sector)`.
If no match is found, an error is thrown with a descriptive message.

### Example
```julia
sector = make_sector_mrio_from_T()
idx = _sector_index_of(sector, "A", "Secondary")  # → 2
````

"""
function _sector_index_of(sector, c::String, s::String)
    for j in 1:length(sector.x)
        if sector.idx_country[j] == c && sector.idx_sector[j] == s
            return j
        end
    end
    error("Sector index not found for (country=$c, sector=$s).")
end
