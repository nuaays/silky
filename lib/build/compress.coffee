_uglify = require 'uglify-js'
_async = require 'async'
_fs = require 'fs-extra'
_path = require 'path'
_cleanCSS = require 'clean-css'
_cheerio = require 'cheerio'

_hookHost = require '../plugin/host'
_utils = require '../utils'
_hooks = require '../plugin/hooks'
_outputRoot = null

#压缩js
compressJS = (file, relativePath, cb)->
  #不需要压缩
  return cb null if not _utils.xPathMapValue('build.compress.js', _utils.config)
  console.log "Compress JS -> #{relativePath}".green
  result = _uglify.minify file
  _utils.writeFile file, result.code
  cb null

#压缩css
compressCSS = (file, relativePath, cb)->
  userOptions = _utils.xPathMapValue('build.compress.css', _utils.config)
  return cb null if not userOptions

  #默认的选项，不支持ie6
  options = compatibility: 'ie7'
  options = userOptions if typeof userOptions is 'object'

  console.log "Compress CSS-> #{relativePath}".green
  content = _utils.readFile file
  content = new _cleanCSS(options).minify content
  _utils.writeFile file, content
  cb null

#压缩html以及internal script
compressHTML = (file, relativePath, cb)->
  compressHtml = _utils.xPathMapValue('build.compress.html', _utils.config)
  compressInternal = _utils.xPathMapValue('build.compress.internal', _utils.config)
  return cb null if not compressHtml and not compressInternal

  content = _utils.readFile file
  console.log "Compress HTML-> #{relativePath}".green
  compressInternal = compressInternal and /<script.+<\/script>/i.test(content)
  rewrite = compressInternal or compressHtml

  #如果不包含script在页面中，则不需要压缩
  if compressInternal
    #压缩internal的script
    content = compressInternalJavascript file, content

  if compressHtml
    #暂时不压缩html，以后考虑压缩html
    content = content

  _utils.writeFile file, content if rewrite
  cb null

#调用cheerio，提取并压缩内联的js
compressInternalJavascript = (file, content)->
  $ = _cheerio.load content
  #跳过模板部分
  $('script').each ()->
    $this = $(this)
    if $this.attr('type') isnt 'html/tpl'
      minify = scriptMinify file, $this.html()
      $this.html minify

  $.html()

#压缩javascript的内容
scriptMinify = (file, content)->
  try
    result = _uglify.minify content, fromString: true
    result.code
  catch e
    console.log "编译JS出错，文件：#{file}".red
    console.log e
    console.log content.red
    return content

#压缩文件，仅压缩html/js/
compressSingleFile = (file, cb)->
  relativePath = _path.relative _outputRoot, file

  #只处理js/html/css
  if /\.js$/i.test file
    compressJS file, relativePath, cb
  else if /\.css$/i.test file
    compressCSS file, relativePath, cb
  else if /\.html?$/i.test file
    compressHTML file, relativePath, cb
  else
    return cb null

#压缩目录
compressDirectory = (dir, cb)->
  files = _fs.readdirSync dir
  index = 0
  _async.whilst(
    -> index < files.length
    ((done)->
      filename = files[index++]
      path = _path.join dir, filename
      compress path, done
    ),
    cb
  )

#混淆整个目录或者文件
compress = (path, cb)->
  stat = _fs.statSync path

  queue = []
#  压缩之前，先让hook处理
  queue.push(
    (done)->
      relativePath = _path.relative _outputRoot, path
      data =
        stat: stat
        path: path
        relativePath: relativePath
        ignore: _utils.simpleMatch _utils.xPathMapValue('build.compress.ignore', _utils.config), relativePath

      _hookHost.triggerHook _hooks.build.willCompress, data, (err)->
        done data.ignore
  )

  #处理文件或者目录
  queue.push(
    (done)->
#      console.log path
      if stat.isDirectory()
        compressDirectory path, done
      else
        compressSingleFile path, done
  )

  #处理完的hook
  queue.push(
    (done)->
      _hookHost.triggerHook _hooks.build.didCompress, null, done
  )

  _async.waterfall queue, -> cb null

#执行压缩
exports.execute = (output, cb)->
  _outputRoot = output
  compress output, (err)-> cb null