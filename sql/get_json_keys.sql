select distinct key, fullkey
from pdfs, json_tree(pdfs.metadata)
where json_tree.type not in ('object');