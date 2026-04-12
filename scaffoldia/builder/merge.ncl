# SPDX-License-Identifier: MPL-2.0
# Scaffoldia - Merge utilities for template composition

# Merge two arrays, removing duplicates
let merge_arrays = fun a b =>
  let combined = a @ b in
  std.array.fold_right
    (fun x acc => if std.array.elem x acc then acc else [x] @ acc)
    []
    combined
in

# Merge file specs, later entries override earlier ones with same path
let merge_files = fun files1 files2 =>
  let paths2 = std.array.map (fun f => f.path) files2 in
  let filtered1 = std.array.filter (fun f => !(std.array.elem f.path paths2)) files1 in
  filtered1 @ files2
in

# Merge two project structures
let merge_structures = fun s1 s2 => {
  directories = merge_arrays s1.directories s2.directories,
  files = merge_files s1.files s2.files,
} in

# Apply a transformation to all files
let map_files = fun f structure => {
  directories = structure.directories,
  files = std.array.map f structure.files,
} in

# Filter files by predicate
let filter_files = fun pred structure => {
  directories = structure.directories,
  files = std.array.filter pred structure.files,
} in

# Add prefix to all file paths
let prefix_paths = fun prefix structure =>
  map_files
    (fun file => file & { path = "%{prefix}/%{file.path}" })
    structure
in

# Flatten nested structures
let flatten = fun structures =>
  std.array.fold_right
    merge_structures
    { directories = [], files = [] }
    structures
in

# Export utilities
{
  merge_arrays,
  merge_files,
  merge_structures,
  map_files,
  filter_files,
  prefix_paths,
  flatten,
}
