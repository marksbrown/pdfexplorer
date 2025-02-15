# PDF Explorer

## Summary 
A database produced by [pdfsplit]("https://github.com/marksbrown/pdfsplit") is navigated by RESTful API.

## Tech Used
Tool is written using :

1. [Redbean](https://redbean.dev/) - Actually Portable Web Server
2. [Fullmoon](https://github.com/pkulchenko/fullmoon) - Fast and minimalistic web framework for redbean
3. [Redbean-template](https://github.com/ProducerMatt/redbean-template) - bash scripts for ease of development

My use case allows me to split digital educational resource pdfs.

## Build Instructions

1. Download latest version of *redbean.com* and *zip.com*
2. Alter make.sh to your needs
3. Run `./make.sh pack' to load files in srv/ into new app
4. Run your app and use the browser



