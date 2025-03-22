select pdfs.id, fullkey, key, value
from pdfs, json_tree(pdfs.metadata)
where key not null;