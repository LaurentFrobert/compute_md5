return {
  name = "lf/compute_md5",
  version = "0.0.1",
  homepage = "xx",
  description = "Luvi test of sqlite package get by lit",
  tags = {"lit", "meta"},
  license = "Apache 2",
  author = { name = "Laurent Frobert" },
  luvi = {
    version = "v2.7.6",
    flavor = "regular",
  },
  dependencies = {
    "SinisterRectus/sqlite3"
    
  },
  files = {    
    "**.lua",
    "!test*"
  }
}
