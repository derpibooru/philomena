/*const fileHeaders = {
  //headers for file types
  png: [],
  jpeg: [],
};*/
      
//https://flaviocopes.com/node-file-stats/
const fs = require('fs')
fs.stat(, (err, stats) => {
  if (err) {
    console.error(err)
    return
  }
  //we have access to the file stats in `stats`
  stats.isFile() //true
  stats.isDirectory() //false
  stats.isSymbolicLink() //false
  stats.size //1024000 //= 1MB
})

