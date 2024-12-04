FROM perl:5.38
COPY . .
RUN cpan -I App::cpanminus
RUN cpanm --notest --quiet --cpanfile cpanfile --installdeps .
CMD ["perl", "snake.pl", "prefork", "-m", "production", "-l", "http://127.0.0.1:8080"]
