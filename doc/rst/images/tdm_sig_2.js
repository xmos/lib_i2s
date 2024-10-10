{ signal: [
  { name: 'FSYNC', wave: '01......|.0....|......|.1.....', node: '.a.b......c' },
  {name: 'BCLK',  wave: '01010101|010101|010101|0101010'},
 { name: 'DATA', wave: 'x..2.2.2|.2.2.2|.2.2.2|.2.2.2.', data: ['MSB(c0)',,,'LSB(c0)','MSB(c1)',,'LSB(c1)','MSB(c2)',,'LSB(cN)','MSB(c0)'], node: '...................'},
  { node : '.A.B......'},
  { node : '.D........C'}
  ],
 edge: ['a|A','A<->B offset','b|B','a|D','D<->C fsync_len','c|C'],
}
