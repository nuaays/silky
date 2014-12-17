###
  支持插件的功能，在启动的时候，会扫描当前工作目录.silky/plugin下的插件
###
_fs = require 'fs-extra'
_path = require 'path'
_common = require '../common'
_host = require './host'
#_plugins = []

#扫描当前工作目录下的插件
scanPlugins = ()->
  folder = 'plugin'
  localPluginDir = _path.join _common.options.workbench, _common.options.identity, folder
  scanPluginsInSpecificDirectory localPluginDir

  #扫描全局的插件，用户可以在全局配置文件中 指定，如果没有指定，则在home目录
  defaultGlobalPluginDir = _path.join _common.homeDirectory(), _common.options.identity, folder
  globalPluginDir = _common.config.globalPluginDirectory || defaultGlobalPluginDir
  scanPluginsInSpecificDirectory globalPluginDir
  _common.debug "Global Plugin -> #{globalPluginDir}".green

registerPlugin = (file, pluginName)->
  try
    plugin = require file
    return console.log("#{filename}不是一个合法的Silky插件") if not plugin.silkyPlugin
    #将插件加入到插件列表，并注册hook
    #_plugins.push plugin
    silky = _host.silkyForHook(pluginName)
    plugin.registerPlugin silky
    _common.debug "Plugin Loaded -> #{pluginName}".green
  catch e
    console.log "插件加载失败->#{file}"
    console.log e

#扫描插件
scanPluginsInSpecificDirectory = (dir)->
  return if not _fs.existsSync dir
  #扫描工作目录
  _fs.readdirSync(dir).forEach (pluginName)->
    file = _path.join dir, pluginName, 'index'
    exists = _fs.existsSync(file + ".coffee") or _fs.existsSync(file + ".js")
    registerPlugin file, pluginName if exists

exports.init = ()->
  scanPlugins()
  #扫描完插件需要重新排序，不然无法实现优先级
  _host.sort()