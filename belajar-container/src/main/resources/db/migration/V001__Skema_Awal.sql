create table product (
    id bigserial,
    code varchar(100) not null,
    name varchar(255) not null,
    price decimal(19,2) not null,
    primary key (id),
    unique (code)
);