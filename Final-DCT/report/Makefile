# Makefile for DCT Report

all: pdf

pdf:
	latexmk -pdf -interaction=nonstopmode main.tex

clean:
	latexmk -C
	rm -f *.aux *.bbl *.blg *.log *.out *.toc *.nav *.snm *.fls *.fdb_latexmk
