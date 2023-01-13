function mat_files = find_matfiles(pathname)


files_in_path = dir(pathname);
file_names = string({files_in_path.name});
mat_files = file_names(contains(file_names, ".mat"));