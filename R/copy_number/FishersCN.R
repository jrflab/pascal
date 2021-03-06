#!/usr/bin/env Rscript

GenCN <- function(gene.cn.a, gene.cn.b, plot.title.main, plot.title.a, plot.title.b, allosome='none', targets.file=NULL, suffix='', threshold.a=TRUE, threshold.b=TRUE, gene.names=TRUE) {

#------
# USAGE
#------

# gene.cn: data frame with the following columns [group, gene, chrom, sample.names... ] - only sample names containing the string "_threshold" are run
#
# gene.cn.a / gene.cn.b: data frames with columns gene, start, end, sample1, sample2 ... [ sample columns should have copy number calls -2..2 ]
#
# plot.title.main: string used for plot title [ verbatim ], and file name [ "a vs b" -> "a_vs_b.pdf" ]
#
# plot.title.a / plot.title.b used for subtitle naming
#
# allosome:
#
#	"none"		= exclude X & Y chromosome
#	"merge"		= treat X & Y coordinates as homologous pair
#	"distinct"	= treat X & Y as seperate, sequential chromosomes
#
# targets.file: should genes be subset by a targets bed file [first 3 cols should be chrom, start, end]
#
# suffix: string appended to end of file names for versioning, use reserved string "now" to use current timestamp
#
# threshold.a / threshold.b: subset columns with those containing string 'threshold'


	#---------------
	# INITIALIZATION
	#---------------

	# libraries
	pacman::p_load(DescTools,dplyr,readr,stringr,tidyr,broom,purrr,magrittr,rlist,crayon,colorspace,ggplot2,grid,gridExtra,RColorBrewer)

	# create output directory
	system("mkdir fishers_cn &>/dev/null")


	#----------
	# FUNCTIONS
	#----------

	message(blue('- initializing'))
	# create gains prevalence object
	GainPrevalence <- function(sample.stats, plot.title, gene.names) {

		stats.melt <-
			sample.stats %>%
			mutate(above=above*100) %>%
			mutate(below=below*-100) %>%
			gather(group, pct, -gene) %>%
			select(Gene=gene,`Prevalance (% cases)`=pct,group) %>%
			mutate(group=factor(group,levels=c('above', 'below')))

		gg <- ggplot(stats.melt , aes(x=Gene, y=`Prevalance (% cases)`, fill=group, width=0.9)) +

		ggtitle(plot.title) +

		geom_bar(stat="identity", data=filter(stats.melt, group=='above')) +
		geom_bar(stat="identity", data=filter(stats.melt, group=='below')) +

		scale_y_continuous(limits=c(-100,100), labels=abs) +
		scale_fill_brewer(type='qualitative', palette='Accent') +

		geom_hline(aes(yintercept=0), colour='#666666') +	# y=0 axis
		geom_vline(xintercept=head(chrom.n$chrom.n,-1)+0.5, colour='#666666', linetype=3)	# chromosome demarcation

		if(gene.names==TRUE) {

			gg <- gg + annotate(geom='text', x=Midx(c(0,chrom.n$chrom.n))+0.5, label=1:max(as.numeric(chrom.n$chrom)), y=Inf, vjust=2, size=5) +	# chromosome enumeration (top)
				theme(	legend.title 		= element_blank(),
						panel.grid.major 	= element_blank(),
						panel.grid.minor    = element_blank(),
						text 				= element_text(size=14),
						axis.title.x		= element_text(vjust=7),
						axis.text.x  		= element_text(angle=90,vjust=0.5,hjust=1,size=5),
						axis.text.y    		= element_text(size=10),
						legend.key   		= element_rect(colour='white', fill=NULL, size=0.1),
						legend.key.size 	= unit(1.4, 'lines'),
						legend.text			= element_text(size=10),
						strip.text.x 		= element_text(colour='white',size=10),
						panel.background 	= element_rect(fill=NA, color='black'),
						plot.margin			= unit(c(1,1,1,1),'cm'))

		} else {

			gg <- gg + annotate(geom='text', x=Midx(c(0,chrom.n$chrom.n))+0.5, label=1:max(as.numeric(chrom.n$chrom)), y=-Inf, vjust=2, size=5) +	# chromosome enumeration (bottom)
			theme(	legend.title 		= element_blank(),
					panel.grid.major 	= element_blank(),
					panel.grid.minor    = element_blank(),
					text 				= element_text(size=14),
					axis.title.x 		= element_blank(),
					axis.text.x 		= element_blank(),
					axis.ticks.x 		= element_blank(),
					axis.title.y		= element_text(vjust=4),
					axis.text.y    		= element_text(size=10),
					legend.key   		= element_rect(colour='white',fill=NULL,size=0.1),
					legend.key.size 	= unit(1.4, 'lines'),
					legend.text			= element_text(size=10),
					strip.text.x 		= element_text(colour='white',size=10),
					panel.background 	= element_rect(fill=NA, color='black'),
					plot.margin			= unit(c(1,1,1,1),'cm'))

		}

		gt <- ggplot_gtable(ggplot_build(gg))
		gt$layout$clip[gt$layout$name=='panel'] <- 'off'
		gt

	}

	# create amplifications prevalence object
	AmpPrevalence <- function(sample.stats, plot.title) {

		stats.melt <-
			sample.stats %>%
			mutate(pct=above*100) %>%
			select(Gene=gene,`Prevalance (% cases)`=pct) %>%
			mutate(group=factor('above'))

		gg <- ggplot(stats.melt , aes(x=Gene, y=`Prevalance (% cases)`, fill=group, width=0.9)) +

		ggtitle(plot.title) +

		geom_bar(stat="identity", data=stats.melt) +

		scale_y_continuous(limits=c(0,100)) +
		scale_fill_brewer(type='qualitative', palette='Accent') +

		geom_hline(aes(yintercept=0), colour='#666666') +	# y=0 axis
		geom_vline(xintercept=head(chrom.n$chrom.n,-1)+0.5, colour='#666666', linetype=3)	# chromosome demarcation

		if(gene.names==TRUE) {

			gg <- gg + annotate(geom='text', x=Midx(c(0,chrom.n$chrom.n))+0.5, label=1:max(as.numeric(chrom.n$chrom)), y=Inf, vjust=2, size=5) +	# chromosome enumeration (top)
				theme(	legend.title 		= element_blank(),
						panel.grid.major 	= element_blank(),
						panel.grid.minor    = element_blank(),
						text 				= element_text(size=14),
						axis.title.x		= element_text(vjust=7),
						axis.text.x  		= element_text(angle=90,vjust=0.5,hjust=1,size=5),
						axis.text.y    		= element_text(size=10),
						legend.key   		= element_rect(colour='white', fill=NULL, size=0.1),
						legend.key.size 	= unit(1.4, 'lines'),
						legend.text			= element_text(size=10),
						strip.text.x 		= element_text(colour='white',size=10),
						panel.background 	= element_rect(fill=NA, color='black'),
						plot.margin			= unit(c(1,1,1,1),'cm'))

		} else {

			gg <- gg + annotate(geom='text', x=Midx(c(0,chrom.n$chrom.n))+0.5, label=1:max(as.numeric(chrom.n$chrom)), y=-Inf, vjust=2, size=5) +	# chromosome enumeration (bottom)
				theme(	legend.title 		= element_blank(),
						panel.grid.major 	= element_blank(),
						panel.grid.minor    = element_blank(),
						text 				= element_text(size=14),
						axis.title.x 		= element_blank(),
						axis.text.x 		= element_blank(),
						axis.ticks.x 		= element_blank(),
						axis.title.y		= element_text(vjust=4),
						axis.text.y    		= element_text(size=10),
						legend.key   		= element_rect(colour='white',fill=NULL,size=0.1),
						legend.key.size 	= unit(1.4, 'lines'),
						legend.text			= element_text(size=10),
						strip.text.x 		= element_text(colour='white',size=10),
						panel.background 	= element_rect(fill=NA, color='black'),
						plot.margin			= unit(c(1,1,1,1),'cm'))

		}

		gt <- ggplot_gtable(ggplot_build(gg))
		gt$layout$clip[gt$layout$name=='panel'] <- 'off'
		gt
	}

	# create gains fishers object
	GainFishers <- function(sample.stats, plot.title) {

		stats.melt <-
			sample.stats %>%
			mutate(above=above*-1) %>%
			mutate(below=below) %>%
			gather(group, pct, -gene) %>%
			select(Gene=gene,`P-value`=pct,group) %>%
			mutate(group=factor(group,levels=c('above', 'below')))

		gg <- ggplot(stats.melt , aes(x=Gene, y=`P-value`, fill=group, width=0.9)) +

		ggtitle(plot.title) +

		geom_bar(stat="identity", data=filter(stats.melt, group=='above')) +
		geom_bar(stat="identity", data=filter(stats.melt, group=='below')) +

		scale_y_continuous(limits=c(-10,10), labels=abs) +
		scale_fill_brewer(type='qualitative', palette='Accent') +

		geom_hline(aes(yintercept=0), colour='#666666') +	# y=0 axis
		geom_vline(xintercept=head(chrom.n$chrom.n,-1)+0.5, colour='#666666', linetype=3)	# chromosome demarcation

		if(gene.names==TRUE) {

			gg <- gg + annotate(geom='text', x=Midx(c(0,chrom.n$chrom.n))+0.5, label=1:max(as.numeric(chrom.n$chrom)), y=Inf, vjust=2, size=5) +	# chromosome enumeration (top)
				theme(	legend.title 		= element_blank(),
						panel.grid.major 	= element_blank(),
						panel.grid.minor    = element_blank(),
						text 				= element_text(size=14),
						axis.title.x		= element_text(vjust=7),
						axis.text.x  		= element_text(angle=90,vjust=0.5,hjust=1,size=5),
						axis.text.y    		= element_text(size=10),
						legend.key   		= element_rect(colour='white', fill=NULL, size=0.1),
						legend.key.size 	= unit(1.4, 'lines'),
						legend.text			= element_text(size=10),
						strip.text.x 		= element_text(colour='white',size=10),
						panel.background 	= element_rect(fill=NA, color='black'),
						plot.margin			= unit(c(1,1,1,1),'cm'))

		} else {

			gg <- gg + annotate(geom='text', x=Midx(c(0,chrom.n$chrom.n))+0.5, label=1:max(as.numeric(chrom.n$chrom)), y=-Inf, vjust=2, size=5) +	# chromosome enumeration (bottom)
			theme(	legend.title 		= element_blank(),
					panel.grid.major 	= element_blank(),
					panel.grid.minor    = element_blank(),
					text 				= element_text(size=14),
					axis.title.x 		= element_blank(),
					axis.text.x 		= element_blank(),
					axis.ticks.x 		= element_blank(),
					axis.title.y		= element_text(vjust=4),
					axis.text.y    		= element_text(size=10),
					legend.key   		= element_rect(colour='white',fill=NULL,size=0.1),
					legend.key.size 	= unit(1.4, 'lines'),
					legend.text			= element_text(size=10),
					strip.text.x 		= element_text(colour='white',size=10),
					panel.background 	= element_rect(fill=NA, color='black'),
					plot.margin			= unit(c(1,1,1,1),'cm'))

		}

		gt <- ggplot_gtable(ggplot_build(gg))
		gt$layout$clip[gt$layout$name=='panel'] <- 'off'
		gt
	}

	# create amplifications fishers object
	AmpFishers <- function(sample.stats, plot.title) {

		stats.melt <-
			sample.stats %>%
			mutate(pct=above*-1) %>%
			select(Gene=gene,`P-value`=pct) %>%
			mutate(group=factor('above'))

		gg <- ggplot(stats.melt , aes(x=Gene, y=`P-value`, fill=group, width=0.9)) +

		ggtitle(plot.title) +

		geom_bar(stat="identity", data=filter(stats.melt, group=='above')) +

		scale_y_continuous(limits=c(0,10)) +
		scale_fill_brewer(type='qualitative', palette='Accent') +

		geom_hline(aes(yintercept=0), colour='#666666') +	# y=0 axis
		geom_vline(xintercept=head(chrom.n$chrom.n,-1)+0.5, colour='#666666', linetype=3)	# chromosome demarcation

		if(gene.names==TRUE) {

			gg <- gg + annotate(geom='text', x=Midx(c(0,chrom.n$chrom.n))+0.5, label=1:max(as.numeric(chrom.n$chrom)), y=Inf, vjust=2, size=5) +	# chromosome enumeration (top)
				theme(	legend.title 		= element_blank(),
						panel.grid.major 	= element_blank(),
						panel.grid.minor    = element_blank(),
						text 				= element_text(size=14),
						axis.title.x		= element_text(vjust=7),
						axis.text.x  		= element_text(angle=90,vjust=0.5,hjust=1,size=5),
						axis.text.y    		= element_text(size=10),
						legend.key   		= element_rect(colour='white', fill=NULL, size=0.1),
						legend.key.size 	= unit(1.4, 'lines'),
						legend.text			= element_text(size=10),
						strip.text.x 		= element_text(colour='white',size=10),
						panel.background 	= element_rect(fill=NA, color='black'),
						plot.margin			= unit(c(1,1,1,1),'cm'))

		} else {

			gg <- gg + annotate(geom='text', x=Midx(c(0,chrom.n$chrom.n))+0.5, label=1:max(as.numeric(chrom.n$chrom)), y=-Inf, vjust=2, size=5) +	# chromosome enumeration (bottom)
			theme(	legend.title 		= element_blank(),
					panel.grid.major 	= element_blank(),
					panel.grid.minor    = element_blank(),
					text 				= element_text(size=14),
					axis.title.x 		= element_blank(),
					axis.text.x 		= element_blank(),
					axis.ticks.x 		= element_blank(),
					axis.title.y		= element_text(vjust=4),
					axis.text.y    		= element_text(size=10),
					legend.key   		= element_rect(colour='white',fill=NULL,size=0.1),
					legend.key.size 	= unit(1.4, 'lines'),
					legend.text			= element_text(size=10),
					strip.text.x 		= element_text(colour='white',size=10),
					panel.background 	= element_rect(fill=NA, color='black'),
					plot.margin			= unit(c(1,1,1,1),'cm'))

		}

		gt <- ggplot_gtable(ggplot_build(gg))
		gt$layout$clip[gt$layout$name=='panel'] <- 'off'
		gt
	}

	# generate table of chromosome breaks
	ChromMod <- function(gene.cn, allosome){

			if(allosome=='distinct') {
					gene.cn %>%
					mutate(.,chrom=ifelse(chrom=='X',23,chrom)) %>%
					mutate(chrom=ifelse(chrom=='Y',24,chrom))
			} else if(allosome =='merge') {
					gene.cn %>% 
					mutate(chrom=ifelse(chrom %in% c('X','Y'), 23, chrom))
			} else {
					gene.cn %>%
					filter(!chrom %in% c('X','Y'))
			}
		}


	# use targets file to select genes
	SubsetTargets <- function(gene.cn, targets) {
		gene.cn %>%
		mutate(chrom=ifelse(chrom=='X',23,ifelse(chrom=='Y',24,chrom))) %>%
		mutate(chrom=as.numeric(chrom)) %>%
		mutate(mid=(start+end)/2) %>%
		rowwise %>%
		mutate(in.target={  # check if gene exists in target file
				any(targets[[chrom]]$start.target <= mid & mid <= targets[[chrom]]$end.target)
			}) %>%
		filter(in.target==TRUE) %>%
		select(-mid,-in.target) %>%
		mutate(chrom=as.character(chrom)) %>%
		mutate(chrom=ifelse(chrom=='23','X',ifelse(chrom=='24','Y',chrom))) %>%
		ungroup
	}


	# calculate % of cases with CN status
	SampleStats <- function(gene.cn, threshold) {
		gene.cn.a %>%
		select(-matches('band|mid|stop')) %>%
		gather(sample,copy.num,-gene,-chrom,-start,-end) %>%
		do({ if(threshold==TRUE){  # conditionally select threshold calls
				filter(., grepl('threshold', sample))
			} else { . } }) %>%
		mutate(n.samples = n_distinct(sample)) %>%
		group_by(gene) %>% arrange(gene) %>%
		# CN status sums
		mutate(amp.sum  = sum(copy.num == 2, na.rm=TRUE)) %>%
		mutate(gain.sum = sum(copy.num == 1, na.rm=TRUE)) %>%
		mutate(loss.sum = sum(copy.num ==-1, na.rm=TRUE)) %>%
		mutate(del.sum  = sum(copy.num == -2, na.rm=TRUE)) %>%
		# CN status percentages
		mutate(amp.pct = amp.sum /n.samples) %>%
		mutate(gain.pct = gain.sum/n.samples) %>%
		mutate(loss.pct = loss.sum/n.samples) %>%
		mutate(del.pct = del.sum /n.samples) %>%
		# over/under sums for Fisher's test [amplicfications]
		mutate(amp.gt = sum(copy.num > 1, na.rm=TRUE)) %>%
		mutate(amp.gt.eq = sum(copy.num >= 1, na.rm=TRUE)) %>%
		mutate(amp.lt.eq = sum(copy.num <= 1, na.rm=TRUE)) %>%
		mutate(amp.lt = sum(copy.num < 1, na.rm=TRUE)) %>%
		# over/under sums for Fisher's test [gains]
		mutate(gain.gt = sum(copy.num > 0, na.rm=TRUE)) %>%
		mutate(gain.gt.eq = sum(copy.num >= 0, na.rm=TRUE)) %>%
		mutate(gain.lt.eq = sum(copy.num <= 0, na.rm=TRUE)) %>%
		mutate(gain.lt = sum(copy.num < 0, na.rm=TRUE)) %>%
		# over/under sums for gain plotting
		mutate(gain.gt.pct = sum(copy.num > 0, na.rm=TRUE)/n.samples) %>%
		mutate(gain.lt.pct = sum(copy.num < 0, na.rm=TRUE)/n.samples) %>%
		select(-c(copy.num,sample)) %>%
		unique
	}


	#----------------
	# DATA PROCESSING
	#----------------

	# rename hgnc to gene if needed
	if('hgnc' %in% names(gene.cn.a)){
		gene.cn.a %<>% rename(gene=hgnc)
	}
	if('hgnc' %in% names(gene.cn.b)){
		gene.cn.b %<>% rename(gene=hgnc)
	}
	# rename stop to end if needed
	if('stop' %in% names(gene.cn.a)){
		gene.cn.a %<>% rename(end=stop)
	}
	if('stop' %in% names(gene.cn.b)){
		gene.cn.b %<>% rename(end=stop)
	}

	message(blue('- subsetting CN tables to target regions'))
	if(!is.null(targets.file)){
		# read in target file, select coordinate columns & split
		targets <-
			read.delim(targets.file, sep='\t', header=FALSE) %>%
			tbl_df %>% .[,1:3] %>%
			setNames(c('chrom','start.target','end.target')) %>%
			mutate(chrom=as.numeric(ifelse(chrom=='X',23,ifelse(chrom=='Y',24,chrom)))) %>%
			arrange(chrom,start.target) %>%
			split(.$chrom)

		# subset genes in target file doing this on one subset is sufficient due to intersection step below
		if(nrow(gene.cn.a) <= nrow(gene.cn.b)) {
			gene.cn.a %<>% SubsetTargets(targets)
		} else {
			gene.cn.b %<>% SubsetTargets(targets)
		}
	}

	# format allosome & filter for overlapping genes
	gene.cn.a %<>% ChromMod(allosome) %>% filter(gene %in% gene.cn.b$gene)
	gene.cn.b %<>% ChromMod(allosome) %>% filter(gene %in% gene.cn.a$gene)


	# generate table of chromosome breaks
	chrom.n <-
		gene.cn.a %>%
		group_by(chrom) %>%
		summarise(chrom.n=n()) %>%
		mutate(chrom.n=cumsum(chrom.n))


	# calculate necessary statistics
	message(blue('- calculating sample statistics'))
	sample.stats <-
		inner_join(SampleStats(gene.cn.a, threshold.a), SampleStats(gene.cn.b, threshold.b) %>% select(-chrom,-start,-end), by='gene', suffix=c('.a','.b')) %>%
		arrange(chrom, start) %>%
		ungroup %>%
		mutate(gene=factor(gene,levels=unique(gene))) %>%
		rowwise %>%
		# amplifications (+)
		mutate(amp.pos.fisher  = fisher.test( data.frame( a = c(amp.gt.a,  amp.lt.eq.a),
														  b = c(amp.gt.b,  amp.lt.eq.b) ) )$p.value ) %>%
		# gains (+)
		mutate(gain.pos.fisher = fisher.test( data.frame( a = c(gain.gt.a, gain.lt.eq.a),
														  b = c(gain.gt.b, gain.lt.eq.b) ) )$p.value ) %>%
		# amplifications (-)
		mutate(amp.neg.fisher  = fisher.test( data.frame( a = c(amp.lt.a,  amp.gt.eq.a),
														  b = c(amp.lt.b,  amp.gt.eq.b) ) )$p.value ) %>%
		# gains (-)
		mutate(gain.neg.fisher = fisher.test( data.frame( a = c(gain.lt.a, gain.gt.eq.a),
														  b = c(gain.lt.b, gain.gt.eq.b) ) )$p.value ) %>%
		# p adjustments
		mutate(amp.pos.fisher.adj  = p.adjust(amp.pos.fisher,  'BH')) %>%
		mutate(gain.pos.fisher.adj = p.adjust(gain.pos.fisher, 'BH')) %>%
		mutate(amp.neg.fisher.adj  = p.adjust(amp.neg.fisher,  'BH')) %>%
		mutate(gain.neg.fisher.adj = p.adjust(gain.neg.fisher, 'BH')) %>%
		# 0.05 cutoffs
		mutate(amp.pos.fisher.adj.cut  = ifelse(amp.pos.fisher.adj  < 0.05, amp.pos.fisher.adj,  NA)) %>%
		mutate(gain.pos.fisher.adj.cut = ifelse(gain.pos.fisher.adj < 0.05, gain.pos.fisher.adj, NA)) %>%
		mutate(amp.neg.fisher.adj.cut  = ifelse(amp.neg.fisher.adj  < 0.05, amp.neg.fisher.adj,  NA)) %>%
		mutate(gain.neg.fisher.adj.cut = ifelse(gain.neg.fisher.adj < 0.05, gain.neg.fisher.adj, NA)) %>%
		# log
		mutate(amp.pos.fisher.adj.cut.log  = log10(amp.pos.fisher.adj.cut)) %>%
		mutate(gain.pos.fisher.adj.cut.log = log10(gain.pos.fisher.adj.cut)) %>%
		mutate(amp.neg.fisher.adj.cut.log  = log10(amp.neg.fisher.adj.cut)) %>%
		mutate(gain.neg.fisher.adj.cut.log = log10(gain.neg.fisher.adj.cut))


	# tables for plotting
	sample.stats.gain.a <-
		sample.stats %>%
		select(gene, above=gain.gt.pct.a, below=gain.lt.pct.a)

	sample.stats.gain.b <-
		sample.stats %>%
		select(gene, above=gain.gt.pct.b, below=gain.lt.pct.b)

	sample.stats.amp.a <-
		sample.stats %>%
		select(gene, above=amp.pct.a)

	sample.stats.amp.b <-
		sample.stats %>%
		select(gene, above=amp.pct.b)
 
	sample.stats.gain.fishers <-
		sample.stats %>%
		select(gene, above=gain.pos.fisher.adj.cut.log, below=gain.neg.fisher.adj.cut.log) %>%
		mutate(above=ifelse(is.na(above),0,above)) %>%
		mutate(below=ifelse(is.na(below),0,below))

	sample.stats.amp.fishers <-
		sample.stats %>%
		select(gene, above=amp.pos.fisher.adj.cut.log) %>%
		mutate(above=ifelse(is.na(above),0,above))


	# column selection & arrangement
	sample.stats %<>%
	select(gene,chrom,start,end,n.samples.a,n.samples.b,amp.pct.a,amp.pct.b,gain.pct.a,gain.pct.b,loss.pct.a,loss.pct.b,del.pct.a,del.pct.b,
	gain.gt.pct.a,gain.lt.pct.a,gain.gt.pct.b,gain.lt.pct.b,
	amp.neg.fisher,amp.neg.fisher.adj,amp.neg.fisher.adj.cut,amp.neg.fisher.adj.cut.log,
	amp.pos.fisher,amp.pos.fisher.adj,amp.pos.fisher.adj.cut,amp.pos.fisher.adj.cut.log,
	gain.neg.fisher,gain.neg.fisher.adj,gain.neg.fisher.adj.cut,gain.neg.fisher.adj.cut.log,
	gain.pos.fisher,gain.pos.fisher.adj,gain.pos.fisher.adj.cut,gain.pos.fisher.adj.cut.log)


	# write data summary
	message(blue('- writing data summary'))
	file.name <- str_c("fishers_cn/",gsub(" ","_",plot.title.main),ifelse(suffix=='now', format(Sys.time(), '.%Y-%m-%d-%H-%M-%S'), ifelse(suffix=='', '', str_c('.',suffix))))
	write_tsv(sample.stats, str_c(file.name,'.txt'))


	#---------------------
	# STATS FUNCTION CALLS
	#---------------------

	message(blue('- building plots'))

	options(device="pdf")

	# call functions & add to plot list
	gg.list <- list( GainPrevalence(sample.stats.gain.a, plot.title=str_c(plot.title.a, " Prevalance [Gains]"), gene.names),
					 GainPrevalence(sample.stats.gain.b, plot.title=str_c(plot.title.b, " Prevalance [Gains]"), gene.names),
					 GainFishers(sample.stats.gain.fishers, plot.title=str_c(plot.title.a, ' x ', plot.title.b, " Fisher's Exact [Gains]")),
					 AmpPrevalence(sample.stats.amp.a, plot.title=str_c(plot.title.a, " Prevalance [Amplifications]")),
					 AmpPrevalence(sample.stats.amp.b, plot.title=str_c(plot.title.b, " Prevalance [Amplifications]")),
					 AmpFishers(sample.stats.amp.fishers, plot.title=str_c(plot.title.a, ' x ', plot.title.b, " Fisher's Exact [Amplifications]")) )


	#---------
	# PLOTTING
	#---------

	# plot to pdf
	suppressWarnings(ggsave(str_c(file.name,'.pdf'), do.call(arrangeGrob, c(gg.list, ncol=1)), device='pdf', width=26, height=26))

	message(green('[ done ]'))

}


