select pdfs.id, fullkey, key, value
from pdfs, json_tree(pdfs.metadata)
where json_tree.type not in ('object');