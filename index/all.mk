all: comments galleries images posts reports tags

comments:
	$(MAKE) -f comments.mk

galleries:
	$(MAKE) -f galleries.mk

images:
	$(MAKE) -f images.mk

posts:
	$(MAKE) -f posts.mk

reports:
	$(MAKE) -f reports.mk

tags:
	$(MAKE) -f tags.mk

clean:
	rm -f ./*.jsonl
