{ signal: [
 { name: 'FSYNC', wave: '0..1.0..|......|......|...10..', node: '...a.b' },
  {name: 'BCLK',  wave: '01010101|010101|010101|0101010', node: '....'},
 { name: 'DATA', wave: 'x..2.2.2|.2.2.2|.2.2.2|.2.2.2.', data: ['MSB(c0)',,,'LSB(c0)','MSB(c1)',,'LSB(c1)','MSB(c2)',,'LSB(cN)','MSB(c0)'], node: '...................'},
{ node:'...A.B'}],
edge: ['a|A','A<->B fsync_len','b|B']
}
