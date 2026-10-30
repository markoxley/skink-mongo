# skink-mongo

Pure-Skink MongoDB driver — BSON codec, OP_MSG wire protocol,
SCRAM authentication, CRUD with cursors, and a `dbx` adapter.
No native client library required.

## Features

- OP_MSG wire protocol (MongoDB ≥ 3.6 / wire version 6+)
- Full BSON codec — documents, arrays, binary, ObjectId, datetime,
  regex, int32/int64/double, all length-explicit
- SCRAM-SHA-256 and SCRAM-SHA-1 authentication over
  `saslStart`/`saslContinue` (SHA-1 mode applies MongoDB's
  `MD5(user:mongo:pw)` digest automatically)
- `find` with multi-batch cursors (`getMore`), `insert` via document
  sequences, `update`, `delete`, `count`, `ping`, arbitrary
  `runCommand`
- `dbx` driver registered under `mongodb://`

## Install

```bash
scales add markoxley/skink-mongo
```

## Usage

```skink
import "mod/markoxley/skink-mongo"
import "mod/markoxley/skink-mongo/mongo_bson"

fn main() {
    c, err := mongo.Dial("mongodb://user:pass@127.0.0.1:27017/mydb")
    ...

    // Find with a filter
    cur, _ := mongo.Find(&c, "users",
        mongo_bson.Doc([]string{"active"}, []mongo_bson.Val{mongo_bson.VBool(true)}))
    for mongo_conn.Next(&cur) {
        d := mongo_conn.Doc(&cur)
        name, _ := mongo_bson.Get(d, "name")
        println(name.Str)
    }

    // Insert
    n, _ := mongo.Insert(&c, "users", []mongo_bson.Val{
        mongo_bson.Doc([]string{"name", "age"},
            []mongo_bson.Val{mongo_bson.VStr("ada"), mongo_bson.VInt(int64(36))}),
    })
}
```

### Via the dbx registry

`Conn.Query`/`Exec` take a JSON command document:

```skink
mongo.Register()
conn, _ := dbx.Open("mongodb://user:pass@host/mydb")
rows, _ := conn.Query(`{"find":"users","filter":{"active":true}}`, nil)
```

Cursor batches map to rows with the union of field names as columns;
scalar replies become a single row.

## DSN

```
mongodb://[user[:password]@]host[:port][/database]
    ?authSource=db          # where auth runs (default: the DSN db)
    &authMechanism=SCRAM-SHA-256 | SCRAM-SHA-1
    &tls=true | ssl=true    # TLS upgrade before handshake —
                            # CA chain + hostname verification enforced
```

## Limitations

- Transactions/sessions are not implemented (`Begin` errors).
- BSON types code(0x0D)/symbol(0x0E)/dbpointer(0x0C)/undefined(0x06)
  are obsolete and rejected on decode.
- OP_MSG responses with the CRC-32C flag set are accepted without
  verification.
- Legacy `OP_QUERY`/`OP_REPLY` (pre-3.6 servers) is not supported.

## Development

```bash
./run_tests.sh        # unit + fake-server suites (incl. real SCRAM math)
./test_live.sh        # podman mongo:7 live test (skips without podman)
./install_local.sh    # verify scales-installability via local mirror
```

Test layout: `bson_test` (codec), `conn_test` (fake server incl.
server-side SCRAM-SHA-256 verification of the client proof),
`dbx_test` (registry + JSON command path), `live_test` (real server,
env-gated on `SKINK_MONGO_DSN`).
