import { x } from "./x";

class Widget {
  handler = () => {
    return x;
  };

  constructor(private items: number[]) {
    this.items = items;
  }

  get size() {
    return this.items.length;
  }

  double() {
    return this.items.map(i => i * 2);
  }
}

function top(a: number) {
  return a + 1;
}

const f = () => {};
