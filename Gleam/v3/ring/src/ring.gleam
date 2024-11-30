import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result

pub type RingMsg {
  Neighbor(Subject(RingMsg))
  DecCounter(Int)
}

pub type DoneMsg {
  Done
}

const num_links = 100

const counter = 100_000

const recv_timeout = 100_000

// Main process //////////////////////////////////////////////////////////////////////////

pub fn main() {
  create_links()
}

fn create_links() {
  let main_ch = process.new_subject()
  let exch_ch = process.new_subject()

  // start links
  let t1 = system_time()
  let link = fn() { link(exch_ch, main_ch) }
  list.range(1, num_links)
  |> list.each(fn(_) { process.start(link, True) })

  io.println(
    int.to_string(num_links)
    <> " processes started in "
    <> float.to_string(exec_time(t1, system_time()))
    <> " seconds!",
  )

  // collect channels
  let channels =
    list.range(1, num_links)
    |> list.map(fn(_) { process.receive(exch_ch, recv_timeout) })

  // check channels
  let #(good, _) = result.partition(channels)

  // set up neighbors
  let t2 = system_time()
  let assert [first, ..rest] = good
  list.zip(good, list.append(rest, [first]))
  |> list.each(fn(elem) {
    case elem {
      #(left, right) -> {
        process.send(left, Neighbor(right))
      }
    }
  })

  io.println(
    int.to_string(num_links)
    <> " processes linked in "
    <> float.to_string(exec_time(t2, system_time()))
    <> " seconds!",
  )

  // send initial counter to head link 
  let t3 = system_time()
  process.send(first, DecCounter(num_links * counter))

  // wait till all messages have been passed
  let assert Ok(Done) = process.receive(main_ch, recv_timeout)
  io.println(
    "All messages sent in "
    <> float.to_string(exec_time(t3, system_time()))
    <> " seconds.",
  )
}

// Link process //////////////////////////////////////////////////////////////////////////

fn link(exch_ch: Subject(Subject(RingMsg)), head_ch: Subject(DoneMsg)) {
  let recv_ch = process.new_subject()
  process.send(exch_ch, recv_ch)
  handler(recv_ch, head_ch)
}

fn handler(recv_ch: Subject(RingMsg), main_ch: Subject(DoneMsg)) {
  case process.receive(recv_ch, recv_timeout) {
    Ok(DecCounter(n)) -> {
      case n {
        0 -> process.send(main_ch, Done)
        _ -> {
          let neighbor = get_registry(next_atom())
          process.send(neighbor, DecCounter(n - 1))
        }
      }
      handler(recv_ch, main_ch)
    }
    Ok(Neighbor(neighbor)) -> {
      put_registry(next_atom(), neighbor)
      handler(recv_ch, main_ch)
    }
    Error(_) -> panic as "Timed out"
  }
}

// Helpers ///////////////////////////////////////////////////////////////////////////////

@external(erlang, "erlang", "put")
fn put_registry(key: Atom, val: Subject(RingMsg)) -> Nil

@external(erlang, "erlang", "get")
fn get_registry(key: Atom) -> Subject(RingMsg)

fn next_atom() -> Atom {
  case atom.from_string("next") {
    Ok(atom) -> atom
    Error(_) -> atom.create_from_string("next")
  }
}

@external(erlang, "erlang", "system_time")
fn system_time() -> Int

fn exec_time(t1: Int, t2: Int) -> Float {
  int.to_float({ t2 - t1 }) /. 1_000_000_000.0
}
