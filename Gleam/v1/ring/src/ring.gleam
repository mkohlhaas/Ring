import gleam/erlang/atom.{type Atom}
import gleam/erlang/process.{type Subject}
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

const recv_timeout = 10_000

// Main process //////////////////////////////////////////////////////////////////////////

pub fn main() {
  create_links()
}

fn create_links() {
  let main_ch = process.new_subject()
  let exch_ch = process.new_subject()

  // start links
  let link = fn() { link(exch_ch, main_ch) }
  list.range(1, num_links)
  |> list.each(fn(_) { process.start(link, True) })

  // collect channels
  let channels =
    list.range(1, num_links)
    |> list.map(fn(_) { process.receive(exch_ch, recv_timeout) })

  // check channels
  let #(good, bad) = result.partition(channels)
  io.debug(bad)
  io.debug(list.length(good))

  // set up neighbors
  let assert [first, ..rest] = good
  list.zip(good, list.append(rest, [first]))
  |> list.each(fn(elem) {
    case elem {
      #(left, right) -> {
        process.send(left, Neighbor(right))
      }
    }
  })

  // send initial counter to head link 
  process.send(first, DecCounter(num_links * counter))

  // wait till all messages have been passed
  let assert Ok(Done) = process.receive(main_ch, recv_timeout)
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
    Error(_) -> panic as "Don't know what happened!"
  }
}

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
