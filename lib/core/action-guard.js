const {
  normalizeExecutableName,
  executablesFromCommand,
} = require("./command-parser")

function firstDangerousExecutable(command, dangerousExecutables) {
  const dangerousSet = new Set(
    (Array.isArray(dangerousExecutables) ? dangerousExecutables : []).map((v) => normalizeExecutableName(v)),
  )
  const executables = executablesFromCommand(command)
  for (const executable of executables) {
    if (dangerousSet.has(executable)) {
      return executable
    }
  }
  return ""
}

module.exports = {
  firstDangerousExecutable,
}
