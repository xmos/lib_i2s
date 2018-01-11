ODGS = $(wildcard *.odg)
PDFS = $(ODGS:.odg=.pdf)

all: $(PDFS)
	@echo PDFs created

_uncropped:
	mkdir _uncropped

_uncropped/%.pdf: %.odg | _uncropped
	soffice -env:UserInstallation=file:///home/$(USER)/.libreoffice-alt --headless --convert-to pdf $< --outdir _uncropped

%.pdf: _uncropped/%.pdf
	pdfcrop $< $@

wavedrom:
	WaveDromEditor source mode.js png mode.png
	WaveDromEditor source left_justified_mode.js png left_justified_mode.png
	WaveDromEditor source tdm_sig_1.js png tdm_sig_1.png
	WaveDromEditor source tdm_sig_2.js png tdm_sig_2.png
	WaveDromEditor source chan_num.js png chan_num.png
	WaveDromEditor source tdm_chan_num.js png tdm_chan_num.png

clean:
	-rm $(PDFS)
	-rm _uncropped/*.pdf
	-rmdir _uncropped
