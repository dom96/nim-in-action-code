import std/[macros, json]

proc createRefType(ident: string, identDefs: seq[NimNode]): NimNode =
  result = newTree(nnkTypeSection,
    newTree(nnkTypeDef,
      newIdentNode(ident),
      newEmptyNode(),
      newTree(nnkRefTy,
        newTree(nnkObjectTy,
          newEmptyNode(),
          newEmptyNode(),
          newTree(nnkRecList,
            identDefs
          )
        )
      )
    )
  )

proc toIdentDefs(stmtList: NimNode): seq[NimNode] =
  expectKind(stmtList, nnkStmtList)
  result = @[]

  for child in stmtList:
    expectKind(child, nnkCall)
    result.add(newIdentDefs(child[0], child[1][0]))

template constructor(ident: untyped): untyped =
  proc `new ident`(): `ident` =
    new result

proc createLoadProc(typeName: string, identDefs: seq[NimNode]): NimNode =
  var cfgIdent = newIdentNode("cfg")
  var filenameIdent = newIdentNode("filename")
  var objIdent = newIdentNode("obj")

  var body = newStmtList()
  body.add quote do:
    var `objIdent` = parseFile(`filenameIdent`)

  for identDef in identDefs:
    let fieldNameIdent = identDef[0]
    let fieldName = $fieldNameIdent.strVal
    case $identDef[1].strVal
    of "string":
      body.add quote do:
        `cfgIdent`.`fieldNameIdent` = `objIdent`[`fieldName`].getStr
    of "int":
      body.add quote do:
        `cfgIdent`.`fieldNameIdent` = `objIdent`[`fieldName`].getInt().int
    else:
      doAssert(false, "Not Implemented")

  return newProc(newIdentNode("load"),
    [newEmptyNode(),
     newIdentDefs(cfgIdent, newIdentNode(typeName)),
     newIdentDefs(filenameIdent, newIdentNode("string"))],
    body)

macro config*(typeName: untyped, fields: untyped): untyped =
  result = newStmtList()

  let identDefs = toIdentDefs(fields)
  result.add createRefType(typeName.strVal, identDefs)
  result.add getAst(constructor(typeName))
  result.add createLoadProc(typeName.strVal, identDefs)

  echo treeRepr(typeName)
  echo treeRepr(fields)

  echo treeRepr(result)
  echo repr(result)

when isMainModule:
  config MyAppConfig:
    address: string
    port: int

  var myConf = newMyAppConfig()
  myConf.load("myappconfig.cfg")
  echo("Address: ", myConf.address)
  echo("Port: ", myConf.port)
