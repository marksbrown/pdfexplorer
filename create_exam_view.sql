create view if not exists exam(id, date, part, examboard, qualification)
as SELECT id, 
json(metadata) -> '$.date' as date, 
json(metadata) -> '$.part' as part, 
json(metadata) -> '$.exam-board' as examboard,
json(metadata) -> '$.level' as qualification 
from pdfs
order by date desc;